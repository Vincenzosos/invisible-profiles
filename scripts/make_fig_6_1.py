"""
Regenerate Fig 6.1 - Italian and Swedish cluster centroids on the joint
fragility-and-burden plane.

Clean redesign (June 2026): de-cluttered label layout.
  - Profile labels are placed manually in the open margins of the plot and
    connected to their centroid by a thin leader line, so the dense low-fragility
    corner no longer collides.
  - The four matched pairs are numbered (1-4) on their connecting lines, and a
    one-line key at the top maps each number to its pair name. This removes the
    floating italic pair-name boxes of the previous version and resolves the
    legend ambiguity.
  - Red rings + bold red labels mark the three country-specific unmatched profiles.
  - No adjustText dependency.
"""

import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

ROOT = Path(__file__).resolve().parent.parent
CENTROIDS_PATH = ROOT / "v9" / "outputs" / "centroids.json"
OUT_PATH = (
    ROOT / "Invisible_Profiles_LaTeX_Overleaf" / "figures"
    / "06_cross_country" / "fig_6_1_matched_pair_scatter.png"
)

# X = physical/functional fragility; Y = subjective burden (see Fig 6.1 caption).
PHYS_VARS = ["sphus", "chronic", "adl", "iadl", "mobility", "phinact"]
SUBJ_NEG = ["eurod", "loneliness"]   # higher = more burdened
SUBJ_POS = ["casp", "hope_future"]   # higher = better -> flip sign


def project(profile, var_names):
    idx = {v: i for i, v in enumerate(var_names)}
    c = profile["center"]
    phys = sum(c[idx[v]] for v in PHYS_VARS) / len(PHYS_VARS)
    neg = sum(c[idx[v]] for v in SUBJ_NEG) / len(SUBJ_NEG)
    pos = sum(c[idx[v]] for v in SUBJ_POS) / len(SUBJ_POS)
    return phys, (neg - pos) / 2


def main():
    d = json.load(open(CENTROIDS_PATH))
    itv = [v["name"] for v in d["italy_full"]["variables"]]
    sev = [v["name"] for v in d["sweden_full"]["variables"]]
    it = {p["name"]: project(p, itv) for p in d["italy_full"]["profiles"]}
    se = {p["name"]: project(p, sev) for p in d["sweden_full"]["profiles"]}

    pairs = [
        ("Fragile",           "Fragile Resigned",   "Fragile"),
        ("Declining",         "Fragile Depressed",  "Social Decline"),
        ("Connected",         "Connected Active",   "Connected Wealthy"),
        ("Socially-oriented", "Traditional Social", "Moderate"),
    ]
    unm_it = {"Moderate Isolated"}
    unm_se = {"Asset Rich", "Wealthy Digital"}

    IT, SE, RED, GREEN = "#1f3a5f", "#2f6fb0", "#c0392b", "#1b9e77"
    fig, ax = plt.subplots(figsize=(11.0, 8.2), dpi=200)

    # matched-pair connectors + numbered marker (t = fraction along line)
    num_t = {"Fragile": 0.5, "Declining": 0.5, "Connected": 0.5, "Socially-oriented": 0.78}
    for i, (nm, a, b) in enumerate(pairs, 1):
        x1, y1 = it[a]; x2, y2 = se[b]
        ax.plot([x1, x2], [y1, y2], color=GREEN, lw=1.8, alpha=.9, zorder=1)
        t = num_t[nm]; xm, ym = x1 + t * (x2 - x1), y1 + t * (y2 - y1)
        ax.scatter(xm, ym, s=150, facecolor="white", edgecolor=GREEN, linewidths=1.3, zorder=4)
        ax.text(xm, ym, str(i), fontsize=8.5, color=GREEN, ha="center", va="center",
                zorder=5, fontweight="bold")

    def marker(x, y, square, unmatched):
        ax.scatter(x, y, marker=("s" if square else "o"), s=170,
                   facecolor=(IT if square else SE), edgecolor=(IT if square else SE),
                   linewidths=.6, zorder=3)
        if unmatched:
            ax.scatter(x, y, marker=("s" if square else "o"), s=470,
                       facecolor="none", edgecolor=RED, linewidths=1.7, zorder=2)
    for l, (x, y) in it.items(): marker(x, y, True, l in unm_it)
    for l, (x, y) in se.items(): marker(x, y, False, l in unm_se)

    # manual label placement: (text_x, text_y, ha, va)
    pos = {
        "Fragile Resigned":   (1.34,  1.16, "center", "bottom"),
        "Fragile":            (1.45,  0.66, "left",   "center"),
        "Fragile Depressed":  (0.52,  0.56, "left",   "center"),
        "Moderate":           (0.52,  0.28, "left",   "center"),
        "Asset Rich":         (0.60,  0.10, "left",   "center"),
        "Wealthy Digital":    (0.78, -0.13, "left",   "center"),
        "Social Decline":     (0.60, -0.44, "left",   "center"),
        "Connected Active":   (0.02, -0.74, "left",   "center"),
        "Connected Wealthy":  (-0.62, -1.02, "center", "top"),
        "Traditional Social": (-1.28, -0.22, "left",   "center"),
        "Moderate Isolated":  (-1.28, -0.58, "left",   "center"),
    }

    def lab(label, x, y, col, bold):
        tx, ty, ha, va = pos[label]
        ax.annotate(label, xy=(x, y), xytext=(tx, ty), ha=ha, va=va, fontsize=8.5,
                    color=col, fontweight=("bold" if bold else "normal"),
                    bbox=dict(facecolor="white", edgecolor=(RED if bold else "#cfcfcf"),
                              lw=(0.9 if bold else 0.5), pad=2, alpha=.96),
                    arrowprops=dict(arrowstyle="-", color="#9a9a9a", lw=0.6, shrinkA=2, shrinkB=5),
                    zorder=6)
    for l, (x, y) in it.items(): lab(l, x, y, (RED if l in unm_it else IT), l in unm_it)
    for l, (x, y) in se.items(): lab(l, x, y, (RED if l in unm_se else "#1c5a8a"), l in unm_se)

    key = "Matched pairs:   ① Fragile    ② Declining    ③ Connected    ④ Socially-oriented"
    ax.text(0.015, 0.985, key, transform=ax.transAxes, fontsize=8.7, va="top", ha="left",
            bbox=dict(facecolor="white", edgecolor="#cccccc", lw=0.6, pad=4))

    ax.axhline(0, color="#bbbbbb", lw=.6, ls="--", zorder=0)
    ax.axvline(0, color="#bbbbbb", lw=.6, ls="--", zorder=0)
    ax.set_xlabel("Physical / functional fragility  (mean z-score; → = more fragile)", fontsize=10)
    ax.set_ylabel("Subjective burden  (mean z-score; ↑ = more burdened)", fontsize=10)
    ax.grid(True, alpha=.22, lw=.4)
    ax.spines["top"].set_visible(False); ax.spines["right"].set_visible(False)

    leg = [
        Line2D([0], [0], marker="s", color="w", markerfacecolor=IT, markersize=10, label="Italy ($k=5$)"),
        Line2D([0], [0], marker="o", color="w", markerfacecolor=SE, markersize=10, label="Sweden ($k=6$)"),
        Line2D([0], [0], color=GREEN, lw=1.8, marker="o", markerfacecolor="white",
               markeredgecolor=GREEN, markersize=8, label="Matched pair (see key)"),
        Line2D([0], [0], marker="o", color="w", markerfacecolor="white", markeredgecolor=RED,
               markeredgewidth=1.7, markersize=12, label="Country-specific (unmatched)"),
    ]
    ax.legend(handles=leg, loc="lower right", fontsize=9, frameon=True, framealpha=.96, edgecolor="#cccccc")

    ax.set_xlim(-1.45, 1.75); ax.set_ylim(-1.2, 1.35)
    plt.tight_layout()
    plt.savefig(OUT_PATH, dpi=300, bbox_inches="tight")
    print(f"Saved: {OUT_PATH}")
    plt.close()


if __name__ == "__main__":
    main()
