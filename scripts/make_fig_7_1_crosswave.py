"""
Fig 7.1 — Cross-wave structural stability (Wave 8 -> Wave 9).

Lollipop chart of the Hungarian-matched centroid distance between each Wave 8
cluster and its Wave 9 counterpart, by country. Values are taken verbatim from
Table 7.4 (\\S7.6); nothing is recomputed here — this is a visualisation of the
published distances. The dashed line at d = 2.0 is the structural-match
threshold: 4/5 Italian and 5/6 Swedish profiles fall below it (preserved), and
exactly one slot per country (Moderate Isolated IT, Asset Rich SE) rearranges
beyond it.

Paths are resolved relative to this script so it is portable across machines.
"""

from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

ROOT = Path(__file__).resolve().parent.parent
OUT_PATH = (
    ROOT / "Invisible_Profiles_LaTeX_Overleaf" / "figures"
    / "07_robustness" / "fig_7_1_crosswave_distance.png"
)

# --- Data from Table 7.4 (Wave 8 cluster -> Wave 9 match, centroid distance) ---
# (label, distance, rearranged?)  ordered ascending within each country.
ITALY = [
    ("Fragile Resigned", 0.47, False),
    ("Fragile Depressed", 0.77, False),
    ("Connected Active", 1.10, False),
    ("Traditional Social", 1.32, False),
    ("Moderate Isolated", 5.71, True),
]
SWEDEN = [
    ("Connected Wealthy", 0.62, False),
    ("Wealthy Digital", 0.72, False),
    ("Moderate", 0.79, False),
    ("Social Decline", 0.83, False),
    ("Fragile", 1.05, False),
    ("Asset Rich", 5.90, True),
]

IT_COLOR = "#1f3a5f"   # dark navy  (Italy)
SE_COLOR = "#6fa8dc"   # light blue (Sweden)
RED_RING = "#c0392b"   # rearranged slot
THRESHOLD = 2.0


def main():
    fig, ax = plt.subplots(figsize=(9.2, 5.6), dpi=200)

    # Build rows top-to-bottom: Italy block, gap, Sweden block.
    rows = []  # (y, label, dist, rearranged, color, country)
    y = 0
    for label, dist, rear in ITALY:
        rows.append((y, label, dist, rear, IT_COLOR, "Italy"))
        y -= 1
    y -= 1  # gap between country blocks
    for label, dist, rear in SWEDEN:
        rows.append((y, label, dist, rear, SE_COLOR, "Sweden"))
        y -= 1

    # Stems + markers
    for yy, label, dist, rear, color, country in rows:
        ax.hlines(yy, 0, dist, color=color, lw=1.6, alpha=0.7, zorder=2)
        ax.scatter(dist, yy, s=130, color=color, zorder=3,
                   edgecolor=(RED_RING if rear else "white"),
                   linewidths=(2.2 if rear else 0.6))
        # value label just right of the marker
        ax.text(dist + 0.12, yy, f"{dist:.2f}", va="center", ha="left",
                fontsize=8.5, color=(RED_RING if rear else "#333333"),
                fontweight=("bold" if rear else "normal"))
        if rear:
            ax.annotate("rearranged slot (d > 2)",
                        xy=(dist, yy), xytext=(dist - 0.4, yy + 0.62),
                        fontsize=8, style="italic", color=RED_RING,
                        ha="right", va="bottom",
                        arrowprops=dict(arrowstyle="-", color=RED_RING, lw=0.8))

    # Y tick labels = profile names
    yticks = [r[0] for r in rows]
    ylabels = [r[1] for r in rows]
    ax.set_yticks(yticks)
    ax.set_yticklabels(ylabels, fontsize=9)
    # colour each tick label by its country
    for tick, (_, _, _, rear, color, _) in zip(ax.get_yticklabels(), rows):
        tick.set_color(RED_RING if rear else color)

    # Country group headers
    it_top = ITALY and rows[0][0]
    se_top = rows[len(ITALY) + 0][0]  # first Sweden row y (after gap)
    ax.text(-0.02, rows[0][0] + 0.9, "Italy ($k = 5$)", fontsize=10,
            fontweight="bold", color=IT_COLOR, ha="left", va="bottom",
            transform=ax.get_yaxis_transform())
    ax.text(-0.02, rows[len(ITALY)][0] + 0.9, "Sweden ($k = 6$)", fontsize=10,
            fontweight="bold", color=SE_COLOR, ha="left", va="bottom",
            transform=ax.get_yaxis_transform())

    # Threshold line
    ax.axvline(THRESHOLD, color="#999999", ls="--", lw=1.0, zorder=1)
    # Caption placed in the free gap between the two country blocks (just right of
    # the dashed line), with a white bbox, so it no longer collides with the
    # Asset Rich row that runs out to d = 5.90.
    gap_y = (rows[len(ITALY) - 1][0] + rows[len(ITALY)][0]) / 2.0
    ax.text(THRESHOLD + 0.12, gap_y,
            "structural-match\nthreshold  $d = 2.0$",
            fontsize=8.5, color="#666666", ha="left", va="center", zorder=4,
            bbox=dict(boxstyle="round,pad=0.25", fc="white", ec="none", alpha=0.95))

    # Cosmetics
    ax.set_xlabel("Hungarian-matched centroid distance, Wave 8 $\\rightarrow$ Wave 9 "
                  "(standardised units)", fontsize=10)
    ax.set_xlim(0, 6.4)
    ax.set_ylim(rows[-1][0] - 1.2, rows[0][0] + 1.6)
    ax.grid(True, axis="x", alpha=0.25, lw=0.4)
    for s in ("top", "right", "left"):
        ax.spines[s].set_visible(False)
    ax.tick_params(axis="y", length=0)

    legend_elements = [
        Line2D([0], [0], marker="o", color="w", markerfacecolor=IT_COLOR,
               markersize=10, label="Italy cluster"),
        Line2D([0], [0], marker="o", color="w", markerfacecolor=SE_COLOR,
               markersize=10, label="Sweden cluster"),
        Line2D([0], [0], marker="o", color="w", markerfacecolor="#cccccc",
               markeredgecolor=RED_RING, markeredgewidth=2.2, markersize=11,
               label="rearranged slot (d > 2)"),
    ]
    ax.legend(handles=legend_elements, loc="center right", fontsize=8.5,
              frameon=True, framealpha=0.95, edgecolor="#cccccc")

    plt.tight_layout()
    plt.savefig(OUT_PATH, dpi=300, bbox_inches="tight")
    print(f"Saved: {OUT_PATH}")
    plt.close()


if __name__ == "__main__":
    main()
