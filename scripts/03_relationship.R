# 03_relationship.R -- Q3: earnings vs age, every earner + weighted band means (the redesign)
# Run from the repository root:  Rscript scripts/03_relationship.R

library(ggplot2)
library(svglite)

# ---- 1. Data: same steps as scripts 01 and 02 ----
person <- read.csv("data/pslm_person_subset.csv")
hh     <- read.csv("data/pslm_hh_subset.csv")
d <- merge(person, hh[, c("hhid", "hhweight", "prov_code", "urban_rural")], by = "hhid")
# which() drops rows where earn_annual is NA (missing)
e <- d[which(d$prov_code == 1 & d$urban_rural == 1 &
             d$age >= 15 & d$age <= 64 & d$earn_annual > 0), ]   # variant 4 = KP rural earners (last two digits of FA24-BEDS-104 are 04)

# ---- 2. Five-year age bands: 15-19, 20-24, ..., 60-64 (ten bands) ----
e$band_no  <- (e$age - 15) %/% 5                 # 0..9
e$band_lab <- paste0(15 + 5 * e$band_no, "-", 19 + 5 * e$band_no)
e$band_mid <- 17 + 5 * e$band_no                 # midpoints 17, 22, ..., 62

# ---- 3. Band table: number of earners and weighted mean = sum(w*x) / sum(w) ----
bands <- do.call(rbind, lapply(split(e, e$band_no), function(g) {
  data.frame(band = g$band_lab[1], midpoint = g$band_mid[1],
             n_earners = nrow(g),
             weighted_mean = round(sum(g$hhweight * g$earn_annual) / sum(g$hhweight)),
             thin = nrow(g) < 30)                # thin band: fewer than 30 unweighted observations
}))
rownames(bands) <- NULL
top <- bands[which.max(bands$weighted_mean), ]   # band with the highest weighted mean

dir.create("results", showWarnings = FALSE)
dir.create("figures", showWarnings = FALSE)
write.csv(bands, "results/band_table_R.csv", row.names = FALSE)
print(bands)

# ---- 4. Figure ----
rs <- function(v) paste0("Rs ", formatC(v, format = "d", big.mark = ","))
n_off <- sum(e$earn_annual < 1e4 | e$earn_annual > 1e7)   # points outside the axis range
n_thin <- sum(bands$thin)

p <- ggplot() +
  # every earner: semi-transparent (alpha 0.15) and jittered sideways by at most 0.4 years
  geom_point(data = e, aes(age, earn_annual),
             position = position_jitter(width = 0.4, height = 0, seed = 104),
             alpha = 0.15, size = 0.9, colour = "#4C78A8") +
  # weighted mean of each band: line + larger marker at the band midpoint
  geom_line(data = bands, aes(midpoint, weighted_mean), colour = "#B03A2E", linewidth = 0.9) +
  geom_point(data = bands, aes(midpoint, weighted_mean, shape = thin),
             colour = "#B03A2E", size = 3.6, stroke = 1.2, fill = "white") +
  scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 1), guide = "none") +
  # direct annotation of the band with the highest weighted mean
  annotate("label", x = top$midpoint, y = top$weighted_mean * 2.6, size = 3.6,
           label = paste0("Highest: ages ", top$band, "\nweighted mean ", rs(top$weighted_mean)),
           colour = "#B03A2E", fill = "white") +
  annotate("segment", x = top$midpoint, xend = top$midpoint,
           y = top$weighted_mean * 1.9, yend = top$weighted_mean * 1.12,
           colour = "#B03A2E", arrow = arrow(length = unit(0.12, "cm"))) +
  scale_y_log10(breaks = 10^(4:7),
                labels = c("Rs 10,000", "Rs 100,000", "Rs 1,000,000", "Rs 10,000,000")) +
  scale_x_continuous(breaks = seq(15, 65, 5), limits = c(14, 65)) +
  coord_cartesian(ylim = c(1e4, 1e7)) +
  labs(title = paste0("Rural KP earners' average pay climbs with age, peaking at ",
                      rs(top$weighted_mean), " at ages ", top$band),
       x = "Age (years)", y = "Annual earnings (rupees, log scale)",
       caption = paste0("Source: PSLM 2019-20 person and household files.\nSample: earners aged 15-64 with earnings > 0 in rural Khyber Pakhtunkhwa (KP) (n = ",                        format(nrow(e), big.mark = ","), ").\n",
                        "Dots: individual earners (jittered, transparent; ", n_off, " outside the axis range not shown).\n",
                        "Red markers: household-weighted (hhweight) mean of each 5-year band.\n",
                        "Hollow markers = bands with fewer than 30 earners (thin bands)",
                        if (n_thin == 0) "; there are none in this sample." else ".")) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold", size = 12.5),
        plot.caption = element_text(hjust = 0, colour = "grey30"),
        panel.grid.minor = element_blank(),
        plot.background = element_rect(fill = "white", colour = NA),
        plot.title.position = "plot", plot.caption.position = "plot")

ggsave("figures/relationship.svg", p, width = 9, height = 6)
cat("Saved figures/relationship.svg\n")

# ---- 5. Supporting facts quoted in the Q4 answer (default figure vs redesign) ----
facts <- data.frame(max_earnings = max(e$earn_annual),
                    n_above_10_million = sum(e$earn_annual > 1e7),
                    n_below_10_thousand = sum(e$earn_annual < 1e4))
write.csv(facts, "results/q4_supporting_facts.csv", row.names = FALSE)
print(facts)
