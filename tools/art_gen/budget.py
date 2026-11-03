"""شمارندهٔ هزینه با توقف خودکار.

هر فراخوانی پیش از اجرا از شمارنده اجازه می‌گیرد. اگر سقف پر شده باشد
`BudgetExceeded` بالا می‌آید و اجرا همان‌جا می‌ایستد — نه اینکه بی‌صدا ادامه
بدهد و قبض بالا برود.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field, asdict
from pathlib import Path

from . import config


class BudgetExceeded(RuntimeError):
	pass


@dataclass
class Ledger:
	"""دفتر هزینه. روی دیسک می‌ماند تا بین اجراها جمع شود."""

	claude_calls: int = 0
	claude_in: int = 0
	claude_out: int = 0
	claude_cache_write: int = 0
	claude_cache_read: int = 0
	cf_calls: int = 0
	cf_steps: int = 0
	cache_hits: int = 0
	notes: list[str] = field(default_factory=list)

	@property
	def claude_usd(self) -> float:
		p = config.CLAUDE_PRICE
		return (
			self.claude_in * p["input"]
			+ self.claude_out * p["output"]
			+ self.claude_cache_write * p["cache_write"]
			+ self.claude_cache_read * p["cache_read"]
		) / 1_000_000.0

	@property
	def cf_neurons(self) -> float:
		return self.cf_steps * config.NEURONS_PER_STEP

	def check_claude(self, projected_usd: float = 0.0) -> None:
		if self.claude_usd + projected_usd > config.BUDGET_USD:
			raise BudgetExceeded(
				"سقف هزینهٔ Claude پر شد: %.4f از %.2f دلار"
				% (self.claude_usd, config.BUDGET_USD)
			)

	def check_cf(self, steps: int) -> None:
		projected = (self.cf_steps + steps) * config.NEURONS_PER_STEP
		if projected > config.CF_NEURONS:
			raise BudgetExceeded(
				"سقف نورون Cloudflare پر شد: %.0f + %.0f از %.0f"
				% (self.cf_neurons, steps * config.NEURONS_PER_STEP, config.CF_NEURONS)
			)

	def report(self) -> str:
		return "\n".join([
			"— هزینه —",
			"  Claude: %d فراخوانی، %d توکن ورودی، %d خروجی، "
			"%d نوشتن کش، %d خواندن کش → %.4f دلار از %.2f"
			% (self.claude_calls, self.claude_in, self.claude_out,
			   self.claude_cache_write, self.claude_cache_read,
			   self.claude_usd, config.BUDGET_USD),
			"  Cloudflare: %d فراخوانی، %d گام → حدود %.0f نورون از %.0f"
			% (self.cf_calls, self.cf_steps, self.cf_neurons, config.CF_NEURONS),
			"  از کش خوانده شد: %d فراخوانی (هزینهٔ صفر)" % self.cache_hits,
		] + ["  یادداشت: " + n for n in self.notes])


def _path() -> Path:
	return config.LOGS / "ledger.json"


def load() -> Ledger:
	p = _path()
	if not p.exists():
		return Ledger()
	raw = json.loads(p.read_text(encoding="utf-8"))
	return Ledger(**raw)


def save(ledger: Ledger) -> None:
	config.ensure_dirs()
	_path().write_text(
		json.dumps(asdict(ledger), ensure_ascii=False, indent=2),
		encoding="utf-8",
	)
