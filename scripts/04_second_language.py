"""04_second_language.py -- Q5: recompute the Q3 band table and redraw the Q3 figure in Python.
Run from the repository root:  python3 scripts/04_second_language.py
Needs: pandas, numpy, matplotlib
"""
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")                      # draw to file, no window needed
import matplotlib.pyplot as plt
from matplotlib.ticker import FixedLocator, FixedFormatter, NullLocator

# ---- 1. Read the two local CSV files and attach weight, province, area ----
person = pd.read_csv("data/pslm_person_subset.csv")
hh = pd.read_csv("data/pslm_hh_subset.csv")
d = person.merge(hh[["hhid", "hhweight", "prov_code", "urban_rural"]], on="hhid", how="inner")

# ---- 2. Variant 4 = KP rural earners (last two digits of FA24-BEDS-104 are 04; age 15-64, earn_annual > 0) ----
# NaN > 0 is False in pandas, so rows with missing earnings drop out automatically
e = d[(d.prov_code == 1) & (d.urban_rural == 1) &
      d.age.between(15, 64) & (d.earn_annual > 0)].copy()

# ---- 3. Five-year bands with integer division (same rule as R: (age - 15) // 5) ----
e["band_no"] = (e.age - 15) // 5
e["band"] = (15 + 5 * e.band_no).astype(str) + "-" + (19 + 5 * e.band_no).astype(str)
e["midpoint"] = 17 + 5 * e.band_no

def wmean(g):
    # weighted mean = sum(w * x) / sum(w)
    return (g.hhweight * g.earn_annual).sum() / g.hhweight.sum()

rows = []
for _, g in e.groupby("band_no"):
    rows.append({"band": g.band.iloc[0], "midpoint": int(g.midpoint.iloc[0]),
                 "n_earners": len(g),
                 # R's round() rounds halves to even; np.round does the same, so the two agree
                 "weighted_mean": int(np.round(wmean(g))),
                 "thin": len(g) < 30})
bands = pd.DataFrame(rows)
os.makedirs("results", exist_ok=True)
os.makedirs("figures", exist_ok=True)
bands.to_csv("results/band_table_python.csv", index=False)
print(bands.to_string(index=False))

# ---- 4. Compare with the R band table, to the rupee ----
r = pd.read_csv("results/band_table_R.csv")
same = (r.band.tolist() == bands.band.tolist()
        and (r.n_earners.values == bands.n_earners.values).all()
        and (r.weighted_mean.values == bands.weighted_mean.values).all())
print("\nR vs Python band tables identical to the rupee:", same)
print("25-29 mean  R:", int(r.loc[r.band == "25-29", "weighted_mean"].iloc[0]),
      " Python:", int(bands.loc[bands.band == "25-29", "weighted_mean"].iloc[0]))

# ---- 5. Redraw the Q3 figure ----
rng = np.random.default_rng(104)
jitter = rng.uniform(-0.4, 0.4, len(e))    # horizontal jitter of at most 0.4 years

top = bands.loc[bands.weighted_mean.idxmax()]
n_off = int(((e.earn_annual < 1e4) | (e.earn_annual > 1e7)).sum())
RED, BLUE = "#B03A2E", "#4C78A8"

fig, ax = plt.subplots(figsize=(9, 6), facecolor="white")
# matplotlib's default marker area is 36 pt^2 and fully opaque -> set small size + alpha 0.15 to match ggplot
ax.scatter(e.age + jitter, e.earn_annual, s=10, alpha=0.15, color=BLUE, linewidths=0)
ax.plot(bands.midpoint, bands.weighted_mean, color=RED, lw=2, zorder=3)
for _, b in bands.iterrows():              # hollow marker for thin bands, filled otherwise
    ax.scatter(b.midpoint, b.weighted_mean, s=75, zorder=4, linewidths=1.5,
               facecolors="white" if b.thin else RED, edgecolors=RED)

ax.set_yscale("log")
ax.set_ylim(1e4, 1e7)
ax.set_xlim(14, 65)
ax.set_xticks(range(15, 66, 5))
# matplotlib defaults to minor log ticks and "10^4" labels -> remove minors, label in rupees
ax.yaxis.set_major_locator(FixedLocator([1e4, 1e5, 1e6, 1e7]))
ax.yaxis.set_major_formatter(FixedFormatter(["Rs 10,000", "Rs 100,000", "Rs 1,000,000", "Rs 10,000,000"]))
ax.yaxis.set_minor_locator(NullLocator())
ax.grid(True, color="#E5E5E5", lw=0.8)
ax.set_axisbelow(True)
for s in ax.spines.values():
    s.set_visible(False)
ax.tick_params(length=0, colors="#444444")

ax.annotate(f"Highest: ages {top.band}\nweighted mean Rs {int(top.weighted_mean):,}",
            xy=(top.midpoint, top.weighted_mean * 1.12), xytext=(top.midpoint, top.weighted_mean * 2.6),
            ha="center", va="center", color=RED, fontsize=10,
            bbox=dict(boxstyle="round,pad=0.3", fc="white", ec=RED, lw=0.6),
            arrowprops=dict(arrowstyle="-|>", color=RED, lw=1))
ax.set_xlabel("Age (years)", fontsize=12)
ax.set_ylabel("Annual earnings (rupees, log scale)", fontsize=12)
fig.suptitle(f"Rural KP earners' average pay climbs with age, peaking at Rs {int(top.weighted_mean):,} at ages {top.band}",
             x=0.01, ha="left", fontweight="bold", fontsize=12)
caption = (f"Source: PSLM 2019-20 person and household files. Sample: earners aged 15-64 with earnings > 0 in rural Khyber Pakhtunkhwa (KP) (n = {len(e):,}).\n"
           f"Dots: individual earners (jittered, transparent; {n_off} outside the axis range not shown).\n"
           "Red markers: household-weighted (hhweight) mean of each 5-year band.\n"
           "Hollow markers = bands with fewer than 30 earners (thin bands)"
           + ("; there are none in this sample." if not bands.thin.any() else "."))
fig.text(0.01, 0.01, caption, ha="left", va="bottom", fontsize=8.5, color="#555555")
fig.subplots_adjust(left=0.14, right=0.97, top=0.93, bottom=0.2)
plt.savefig("figures/relationship_python.svg", facecolor="white")
print("Saved figures/relationship_python.svg")
