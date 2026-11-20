# Final report

LaTeX source for the UCS503P final (end-semester) report on Campus Companion. It
builds on the mid-semester report: the mid-semester chapters are kept and updated,
and the new chapters sit in `chapters/`.

## Files

| File | What it is |
|---|---|
| `main.tex` | The report: title page and Chapters 1 to 4, 7 and 8 |
| `chapters/testing.tex` | Chapter 5, Testing |
| `chapters/results.tex` | Chapter 6, Results and Analysis |
| `chapters/journal.tex` | Chapter 9, Project Journal |
| `references.bib` | Bibliography, biblatex + biber |
| `tietreport.cls` | The TIET document class, copied from the shared Overleaf template |
| `figures/*.puml` | PlantUML sources for every diagram |
| `figures/*.png` | Rendered diagrams |
| `figures/skin.iuml` | Shared styling included by every `.puml` |
| `figures/screens/` | Simulator screenshots used in Chapter 5 |
| `figures/charts/` | Charts and test-run images used in Chapters 5 and 6 |
| `main.pdf` | The built report |

## Building on Overleaf

Upload `main.tex`, `references.bib`, and the `chapters/` and `figures/` folders into
the project that already has `tietreport.cls`. Set the compiler to pdfLaTeX and the
bibliography tool to Biber (Menu -> Settings). Recompile.

## Building locally

Needs a TeX distribution with biblatex, biber, longtable and float:

    pdflatex main && biber main && pdflatex main && pdflatex main

## Regenerating the diagrams

Needs Java and Graphviz (`brew install graphviz`); PlantUML's built-in Smetana
layout tangles the larger diagrams. From `figures/`:

    GRAPHVIZ_DOT=$(which dot) java -jar plantuml.jar -tpng -Sdpi=200 *.puml

PlantUML names each PNG after the `@startuml` tag, which uses underscores; rename
them to the hyphenated names `main.tex` uses.

## Where the numbers come from

- Test results: `npm test` in `backend/` (see the header of `backend/test/api.test.js`
  for the test database setup) and `flutter test` in `frontend/`.
- Response times and scaling: measured on 20 Nov 2026 against a local server on a
  test database, as described in Chapter 6.
- Code size: line counts of `backend/*.js` and `frontend/lib/**/*.dart` at each commit.
