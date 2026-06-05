"""
Regenerate Fig 6.1 — Italian and Swedish cluster centroids on the joint
fragility-and-burden plane.

Fixes vs the original 18 May version:
  - Red ring outlines only on the 3 unmatched profiles
    (Moderate Isolated IT, Asset Rich SE, Wealthy Digital SE).
  - Pair-name italic annotations placed at the midpoint of each connecting line
    with a white background box, so they survive marker overlap.
  - Profile labels positioned automatically with adjustText so the bottom-left
    cluster does not collide.
  - Larger figure footprint (full-page) for breathing room.
"""

import json
import os
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Patch
from matplotlib.lines import Line2D
from adjustText import adjust_text

# Paths are resolved relative to this script's location so the figure can be
# regenerated from the project root on any machine (no hard-coded session path).
ROOT = Path(__file__).resolve().parent.parent
CENTROIDS_PATH = ROOT / "v9" / "outputs" / "centroids.json"
OUT_PATH = (
    ROOT / "Invisible_Profiles_LaTeX_Overleaf" / "figures"
    / "06_cross_country" / "fig_6_1_matched_pair_scatter.png"
)

# Axis definitions per caption of Fig 6.1:
#  X = physical/functional fragility: mean z(sphus, chronic, ADL, IADL, mobility, phinact)
#  Y = subjective burden: (mean z(eurod, loneliness) - mean z(casp, hope_future)) / 2
PHYS_VARS = ["sphus", "chronic", "adl", "iadl", "mobility", "phinact"]
SUBJ_NEG = ["eurod", "loneliness"]   # higher = more burdened
SUBJ_POS = ["casp", "hope_future"]   # higher = better → flip sign


def project(profile, var_names):
    """Project a centroid into the (physical, subjective) z-score plane."""
    idx = {v: i for i, v in enumerate(var_names)}
    c = profile["center"]
    phys = sum(c[idx[v]] for v in PHYS_VARS) / len(PHYS_VARS)
    neg = sum(c[idx[v]] for v in SUBJ_NEG) / len(SUBJ_NEG)
    pos = sum(c[idx[v]] for v in SUBJ_POS) / len(SUBJ_POS)
    subj = (neg - pos) / 2
    return phys, subj


def main():
    with open(CENTROIDS_PATH) as f:
        d = json.load(f)

    it_vars = [v["name"] for v in d["italy_full"]["variables"]]
    se_vars = [v["name"] for v in d["sweden_full"]["variables"]]

    it = {p["name"]: project(p, it_vars) for p in d["italy_full"]["profiles"]}
    se = {p["name"]: project(p, se_vars) for p in d["sweden_full"]["profiles"]}

    # Hungarian-matched pairs (from §6.2 / Table 6.1)
    pairs = [
        ("Fragile",          "Fragile Resigned",   "Fragile"),
        ("Declining",        "Fragile Depressed",  "Moderate"),
        ("Connected",        "Connected Active",   "Connected Wealthy"),
        ("Socially-oriented", "Traditional Social", "Social Decline"),
    ]
    # Unmatched (country-specific) profiles
    unmatched_it = {"Moderate Isolated"}
    unmatched_se = {"Asset Rich", "Wealthy Digital"}

    # Colours coherent with the rest of the thesis (sober blue palette,
    # IT darker / SE lighter — matches Fig 1.1 and Fig 6.2).
    IT_COLOR = "#1f3a5f"   # dark navy
    SE_COLOR = "#6fa8dc"   # light blue
    RED_RING = "#c0392b"

    fig, ax = plt.subplots(figsize=(11.5, 8.0), dpi=200)

    # --- 1. Connecting lines for matched pairs (drawn first, behind markers)
    for pair_name, it_label, se_label in pairs:
        x1, y1 = it[it_label]
        x2, y2 = se[se_label]
        ax.plot(
            [x1, x2], [y1, y2],
            color="#999999", lw=1.0, alpha=0.6, zorder=1,
        )

    # --- 2. Markers
    # Italy (squares)
    for label, (x, y) in it.items():
        is_unmatched = label in unmatched_it
        ax.scatter(
            x, y,
            marker="s", s=180,
            facecolor=IT_COLOR, edgecolor=(RED_RING if is_unmatched else IT_COLOR),
            linewidths=(2.5 if is_unmatched else 0.6),
            zorder=3,
        )
        if is_unmatched:
            # Extra outer red ring for stronger affordance
            ax.scatter(
                x, y, marker="s", s=420,
                facecolor="none", edgecolor=RED_RING,
                linewidths=1.6, zorder=2,
            )

    # Sweden (circles)
    for label, (x, y) in se.items():
        is_unmatched = label in unmatched_se
        ax.scatter(
            x, y,
            marker="o", s=180,
            facecolor=SE_COLOR, edgecolor=(RED_RING if is_unmatched else SE_COLOR),
            linewidths=(2.5 if is_unmatched else 0.6),
            zorder=3,
        )
        if is_unmatched:
            ax.scatter(
                x, y, marker="o", s=420,
                facecolor="none", edgecolor=RED_RING,
                linewidths=1.6, zorder=2,
            )

    # --- 3. Pair-name annotations at the midpoint of each connecting line
    # Manual nudge per pair so annotations don't sit on top of the line itself
    pair_nudges = {
        "Fragile":           (-0.26,  0.11),   # pushed up-left into open space, clear of the Fragile Resigned label
        "Declining":         (-0.10,  0.04),
        "Connected":         (-0.08, -0.06),   # pushed below-left to clear cluster
        "Socially-oriented": (-0.15,  0.10),   # pushed up-left to clear Social Decline label
    }
    for pair_name, it_label, se_label in pairs:
        x1, y1 = it[it_label]
        x2, y2 = se[se_label]
        xm, ym = (x1 + x2) / 2, (y1 + y2) / 2
        dx, dy = pair_nudges.get(pair_name, (0.0, 0.06))
        ax.text(
            xm + dx, ym + dy, pair_name,
            fontsize=9, style="italic", color="#444444",
            ha="center", va="bottom",
            bbox=dict(
                facecolor="white", edgecolor="#dddddd", linewidth=0.4,
                pad=2.5, alpha=1.0,
            ),
            zorder=6,   # above profile labels so pair annotations are never covered
        )

    # --- 4. Profile labels with adjustText (auto-positioned with leader lines)
    texts = []
    for label, (x, y) in it.items():
        is_unmatched = label in unmatched_it
        txt = ax.text(
            x, y, label,
            fontsize=8, color=(RED_RING if is_unmatched else IT_COLOR),
            fontweight=("bold" if is_unmatched else "normal"),
            bbox=dict(
                facecolor="white",
                edgecolor=(RED_RING if is_unmatched else "#cccccc"),
                linewidth=0.6, pad=2, alpha=0.95,
            ),
            zorder=5,
        )
        texts.append(txt)
    for label, (x, y) in se.items():
        is_unmatched = label in unmatched_se
        txt = ax.text(
            x, y, label,
            fontsize=8, color=(RED_RING if is_unmatched else "#1c5a8a"),
            fontweight=("bold" if is_unmatched else "normal"),
            bbox=dict(
                facecolor="white",
                edgecolor=(RED_RING if is_unmatched else "#cccccc"),
                linewidth=0.6, pad=2, alpha=0.95,
            ),
            zorder=5,
        )
        texts.append(txt)

    adjust_text(
        texts, ax=ax,
        expand=(2.0, 2.4),
        force_text=(1.3, 1.7),
        force_static=(0.8, 1.1),
        force_pull=(0.005, 0.005),
        arrowprops=dict(
            arrowstyle="-",
            color="#888888",
            lw=0.6, shrinkA=4, shrinkB=4,
        ),
    )

    # --- 5. Axis cosmetics
    ax.axhline(0, color="#bbbbbb", lw=0.6, ls="--", zorder=0)
    ax.axvline(0, color="#bbbbbb", lw=0.6, ls="--", zorder=0)
    ax.set_xlabel(
        "Physical / functional fragility  (mean z-score; → = more fragile)",
        fontsize=10,
    )
    ax.set_ylabel(
        "Subjective burden  (mean z-score; ↑ = more burdened)",
        fontsize=10,
    )
    # No internal title: the LaTeX \caption of Figure 6.1 supplies it, and a
    # baked-in title would duplicate the caption (thesis convention: figures
    # carry no internal title).
    ax.grid(True, alpha=0.25, lw=0.4)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    # --- 6. Custom legend
    legend_elements = [
        Line2D([0], [0], marker="s", color="w", markerfacecolor=IT_COLOR,
               markersize=10, label="Italy (k = 5)"),
        Line2D([0], [0], marker="o", color="w", markerfacecolor=SE_COLOR,
               markersize=10, label="Sweden (k = 6)"),
        Line2D([0], [0], color="#999999", lw=1.0, label="Hungarian-matched pair"),
        Line2D([0], [0], marker="o", color="w",
               markerfacecolor="white", markeredgecolor=RED_RING, markeredgewidth=1.6,
               markersize=12, label="Country-specific (unmatched)"),
    ]
    ax.legend(
        handles=legend_elements, loc="lower right",
        fontsize=9, frameon=True, framealpha=0.95, edgecolor="#cccccc",
    )

    # --- 7. Set axis limits with margin
    xs = [v[0] for v in list(it.values()) + list(se.values())]
    ys = [v[1] for v in list(it.values()) + list(se.values())]
    xpad = 0.45
    ypad = 0.35
    # Extra room on the lower-left, where four low-fragility/low-burden centroids
    # (Connected Active, Connected Wealthy, Traditional Social, Moderate Isolated)
    # crowd together — gives adjustText space to spread their labels outward.
    ax.set_xlim(min(xs) - (xpad + 0.35), max(xs) + xpad)
    ax.set_ylim(min(ys) - (ypad + 0.28), max(ys) + ypad)

    plt.tight_layout()

    plt.savefig(OUT_PATH, dpi=300, bbox_inches="tight")
    print(f"Saved: {OUT_PATH}")
    plt.close()


if __name__ == "__main__":
    main()
