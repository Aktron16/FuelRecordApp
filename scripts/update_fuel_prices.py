#!/usr/bin/env python3
"""Update fuel_price.json from public monthly fuel-price sources."""

from __future__ import annotations

import argparse
import json
import logging
import os
import re
from copy import deepcopy
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import quote

import requests
from bs4 import BeautifulSoup

ROOT = Path(__file__).resolve().parents[1]
DATA_FILE = ROOT / "fuel_price.json"
USER_AGENT = "FuelRecordApp monthly fuel price updater/1.0"
REQUEST_TIMEOUT = 30
LITRES_PER_US_GALLON = 3.78541
LOG = logging.getLogger("update_fuel_prices")

# Broad currency-aware bounds reject unit mistakes while allowing normal prices.
MAX_PRICE_BY_CURRENCY = {
    "AED": 20, "ARS": 20_000, "AUD": 20, "BRL": 30, "CAD": 25,
    "CHF": 25, "CLP": 5_000, "CNY": 100, "COP": 30_000, "CZK": 150,
    "DKK": 40, "EUR": 25, "GBP": 25, "IDR": 50_000, "INR": 500,
    "JPY": 1_000, "KRW": 5_000, "KWD": 10, "MXN": 100, "MYR": 30,
    "NOK": 40, "NZD": 25, "PEN": 30, "PHP": 300, "PLN": 60,
    "QAR": 20, "RON": 30, "SAR": 20, "SEK": 40, "SGD": 25, "THB": 200,
    "TRY": 300, "USD": 20, "VND": 100_000, "ZAR": 50,
}


def load_dataset() -> dict[str, Any]:
    with DATA_FILE.open(encoding="utf-8") as file:
        dataset = json.load(file)
    if dataset.get("schemaVersion") != 1 or len(dataset.get("countries", {})) != 45:
        raise ValueError("fuel_price.json must contain schemaVersion 1 and 45 countries")
    return dataset


def request_text(session: requests.Session, url: str, **kwargs: Any) -> str:
    response = session.get(
        url,
        timeout=REQUEST_TIMEOUT,
        headers={"User-Agent": USER_AGENT, "Accept-Language": "en"},
        **kwargs,
    )
    response.raise_for_status()
    return response.text


def parse_numbers(text: str) -> list[float]:
    values = []
    for raw in re.findall(r"(?<![\w.])\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,3})?(?![\w.])", text):
        if "," in raw and "." in raw:
            raw = raw.replace(",", "") if raw.rfind(".") > raw.rfind(",") else raw.replace(".", "").replace(",", ".")
        elif "," in raw:
            raw = raw.replace(",", ".") if len(raw.rsplit(",", 1)[1]) <= 2 else raw.replace(",", "")
        try:
            value = float(raw)
        except ValueError:
            continue
        if value > 0:
            values.append(value)
    return values


def labelled_price(text: str, labels: tuple[str, ...]) -> float | None:
    normalized = " ".join(text.split())
    for label in labels:
        match = re.search(
            rf"{re.escape(label)}.{{0,100}}?(\d+(?:[.,]\d{{1,3}})?)",
            normalized,
            flags=re.IGNORECASE,
        )
        if match:
            numbers = parse_numbers(match.group(1))
            if numbers:
                return numbers[0]
    return None


def valid_price(value: Any, currency: str) -> bool:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return False
    return not isinstance(value, bool) and 0 < number <= MAX_PRICE_BY_CURRENCY.get(currency, 1_000)


def grade_category(grade: str) -> str | None:
    lower = grade.lower()
    if any(token in lower for token in ("diesel", "gazole", "gasolio", "motorin", "acpm", "nafta", "do ")):
        return "diesel"
    if any(token in lower for token in ("lpg", "gnv", "cng", "autogas", "metano", "biodiesel")):
        return None
    return "gasoline"


def fetch_uae_prices(session: requests.Session) -> dict[str, float]:
    text = BeautifulSoup(request_text(session, "https://fuelpriceuae.com/"), "lxml").get_text(" ", strip=True)
    aliases = {
        "Special 95": ("Special 95",),
        "Super 98": ("Super 98",),
        "E-Plus 91": ("E-Plus 91",),
        "Diesel": ("Diesel",),
    }
    return {
        grade: value
        for grade, labels in aliases.items()
        if (value := labelled_price(text, labels)) is not None
    }


def fetch_us_eia_prices(session: requests.Session) -> dict[str, float]:
    products = {
        "Regular (87)": "EPM0",
        "Midgrade (89)": "EPMM",
        "Premium (93)": "EPMP",
        "Diesel": "EPD2",
    }
    endpoint = "https://api.eia.gov/v2/petroleum/pri/gnd/data/"
    prices = {}
    for grade, product in products.items():
        response = session.get(
            endpoint,
            params={
                "api_key": os.getenv("EIA_API_KEY", "DEMO_KEY"),
                "frequency": "weekly",
                "data[0]": "value",
                "facets[duoarea][]": "NUS",
                "facets[product][]": product,
                "sort[0][column]": "period",
                "sort[0][direction]": "desc",
                "length": "1",
            },
            timeout=REQUEST_TIMEOUT,
            headers={"User-Agent": USER_AGENT},
        )
        response.raise_for_status()
        rows = response.json().get("response", {}).get("data", [])
        if rows:
            prices[grade] = float(rows[0]["value"]) / LITRES_PER_US_GALLON
    return prices


def fetch_global_prices(session: requests.Session, country: dict[str, Any]) -> dict[str, float]:
    slug = quote(country["name"].replace(" ", "_"))
    prices = {}
    for product, aliases in (
        ("gasoline", ("gasoline", "petrol", "benzine", "gasolina")),
        ("diesel", ("diesel", "gazole", "gasolio")),
    ):
        url = f"https://www.globalpetrolprices.com/{slug}/{product}_prices/"
        soup = BeautifulSoup(request_text(session, url), "lxml")
        text = soup.get_text(" ", strip=True)
        value = next((labelled_price(text, (alias,)) for alias in aliases), None)
        if value is not None:
            prices[product] = value
    return prices


def collect_prices(dataset: dict[str, Any], session: requests.Session) -> dict[str, dict[str, float]]:
    prices = {}
    for code, country in dataset["countries"].items():
        try:
            if code == "AE":
                values = fetch_uae_prices(session)
            elif code == "US":
                values = fetch_us_eia_prices(session)
            else:
                values = fetch_global_prices(session, country)
            prices[code] = values
            LOG.info("%s: received %d source values", code, len(values))
        except (requests.RequestException, ValueError, KeyError) as error:
            LOG.warning("%s: source unavailable; retaining previous values (%s)", code, error)
            prices[code] = {}
    return prices


def update_dataset(
    dataset: dict[str, Any],
    prices: dict[str, dict[str, float]],
    today: date,
) -> dict[str, Any]:
    updated = deepcopy(dataset)
    updated["month"] = today.strftime("%Y-%m")
    updated["updatedAt"] = today.isoformat()
    for code, country in updated["countries"].items():
        country_prices = prices.get(code, {})
        for grade in country["grades"]:
            value = country_prices.get(grade)
            if value is None:
                category = grade_category(grade)
                value = country_prices.get(category) if category else None
            if valid_price(value, country["currencyCode"]):
                country["grades"][grade] = round(float(value), 4)
    return updated


def validate_dataset(dataset: dict[str, Any], original: dict[str, Any]) -> None:
    if set(dataset) != {"schemaVersion", "month", "updatedAt", "countries"}:
        raise ValueError("top-level JSON keys changed")
    if dataset["schemaVersion"] != 1 or len(dataset["countries"]) != 45:
        raise ValueError("country schema changed")
    if not re.fullmatch(r"\d{4}-\d{2}", dataset["month"]):
        raise ValueError("invalid month")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", dataset["updatedAt"]):
        raise ValueError("invalid updatedAt")
    for code, old_country in original["countries"].items():
        country = dataset["countries"].get(code)
        if country is None or set(country) != {"name", "currencyCode", "grades"}:
            raise ValueError(f"country structure changed for {code}")
        if country["name"] != old_country["name"] or country["currencyCode"] != old_country["currencyCode"]:
            raise ValueError(f"country metadata changed for {code}")
        if set(country["grades"]) != set(old_country["grades"]):
            raise ValueError(f"grade keys changed for {code}")
        if not all(valid_price(value, country["currencyCode"]) for value in country["grades"].values()):
            raise ValueError(f"invalid price for {code}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", help="Override UTC date (YYYY-MM-DD), useful for testing")
    args = parser.parse_args()
    today = date.fromisoformat(args.date) if args.date else datetime.now(timezone.utc).date()

    original = load_dataset()
    with requests.Session() as session:
        updated = update_dataset(original, collect_prices(original, session), today)
    validate_dataset(updated, original)
    DATA_FILE.write_text(
        json.dumps(updated, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    LOG.info("Updated %s for %s", DATA_FILE, updated["month"])


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    main()
