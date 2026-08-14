# notilite — spec (mini-spec per dry-run SDD)

US: come sviluppatore voglio formattare e filtrare eventi di log con livelli ordinati.

AC1 — formatter (owns: src/formatter.py, tests/test_formatter.py):
- formatta(msg, livello='info') → "[LIVELLO] msg" (livello maiuscolo).
- Livelli validi: debug, info, warn, error. Livello ignoto ⇒ ValueError.
- doneWhen: `uv run --with pytest pytest -q tests/test_formatter.py` verde.

AC2 — filter (owns: src/filter.py, tests/test_filter.py):
- filtra(eventi, minimo) → i soli eventi con livello >= minimo (ordine debug<info<warn<error),
  ordine di input preservato. Livello ignoto (in evento o minimo) ⇒ ValueError.
- doneWhen: `uv run --with pytest pytest -q tests/test_filter.py` verde.

read-first: src/formatter.py, src/filter.py (stub NotImplementedError da implementare).
I test NON esistono: vanno scritti prima dell'implementazione (RED-phase).
