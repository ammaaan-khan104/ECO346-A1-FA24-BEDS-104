# 02_distribution.R -- Q2: weighted histogram of annual earnings (log10 scale)
# Run from the repository root:  Rscript scripts/02_distribution.R

library(ggplot2)
library(svglite)

# ---- 1. Data: same steps as script 01 ----
person <- read.csv("data/pslm_person_subset.csv")
hh     <- read.csv("data/pslm_hh_subset.csv")
d <- merge(person, hh[, c("hhid", "hhweight", "prov_code", "urban_rural")], by = "hhid")
# which() drops rows where earn_annual is NA (missing) -- NA > 0 is NA, not FALSE
e <- d[which(d$prov_code == 1 & d$urban_rural == 1 &
           d$age >= 15 & d$age <= 64 & d$earn_annual > 0), ]   # variant 4 = KP rural earners (last two digits of FA24-BEDS-104 are 04)

# ---- 2. Weighted quantile, exactly the definition in the assignment ----
# sort by x, cumulative share of weight, smallest x whose share >= p
wquant <- function(x, w, p) {
  o <- order(x)
  x <- x[o]; w <- w[o]
  share <- cumsum(w) / sum(w)
  x[which(share >= p - 1e-12)[1]]     # 1e-12 only guards against floating-point noise
}

x <- e$earn_annual
w <- e$hhweight

n_earners <- nrow(e)
w_median  <- wquant(x, w, 0.5)
u_median  <- median(x)                # unweighted median
p10       <- wquant(x, w, 0.1)
p90       <- wquant(x, w, 0.9)
ratio     <- round(p90 / p10, 2)

# ---- 3. Keep only earners between Rs 10,000 and Rs 10,000,000 ----
in_range   <- x >= 1e4 & x <= 1e7
n_excluded <- sum(!in_range)
xr <- log10(x[in_range])
wr <- w[in_range]

# ---- 4. Weighted histogram by hand: bins 0.1 wide from 4.0 to 7.0 (30 bins) ----
bin <- floor((xr - 4) / 0.1 + 1e-9) + 1      # bin number 1..30 (left-closed bins)
bin[bin > 30] <- 30                          # the value 7.0 exactly goes in the last bin
wsum <- tapply(wr, factor(bin, levels = 1:30), sum)
wsum[is.na(wsum)] <- 0
density <- as.numeric(wsum) / (sum(wr) * 0.1)   # density per log10 unit (area = 1)
hist_df <- data.frame(xmin = 4 + 0.1 * (0:29), xmax = 4 + 0.1 * (1:30), density = density)

# ---- 5. Figure ----
rs <- function(v) paste0("Rs ", formatC(v, format = "d", big.mark = ","))
ymax <- max(density)

p <- ggplot(hist_df) +
  geom_rect(aes(xmin = xmin, xmax = xmax, ymin = 0, ymax = density),
            fill = "#4C78A8", colour = "white", linewidth = 0.3) +
  geom_vline(xintercept = log10(w_median), linetype = "dashed", colour = "#222222") +
  geom_vline(xintercept = log10(p90),      linetype = "dashed", colour = "#B03A2E") +
  annotate("text", x = log10(w_median) - 0.04, y = ymax * 1.12, hjust = 1,
           label = paste0("Weighted median\n", rs(w_median)), size = 3.6, colour = "#222222") +
  annotate("text", x = log10(p90) + 0.04, y = ymax * 0.80, hjust = 0,
           label = paste0("90th percentile\n", rs(p90)), size = 3.6, colour = "#B03A2E") +
  scale_x_continuous(breaks = 4:7, labels = c("Rs 10,000", "Rs 100,000", "Rs 1,000,000", "Rs 10,000,000"),
                     expand = expansion(add = c(0.1, 0.15))) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.08))) +
  labs(title = paste0("Half of rural KP earners make ", rs(w_median),
                      " a year or less; the top tenth make ", rs(p90), " or more"),
       x = "Annual earnings (rupees, log scale)",
       y = "Density per log10 unit",
       caption = paste0("Source: PSLM 2019-20 person and household files.\nSample: earners aged 15-64 with earnings > 0 in rural Khyber Pakhtunkhwa (KP) (n = ",                        format(n_earners, big.mark = ","), ").\n",
                        "Weighted by household weight (hhweight). ", n_excluded,
                        " earners outside Rs 10,000 - Rs 10,000,000 are excluded from the histogram.")) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold", size = 12.5),
        plot.caption = element_text(hjust = 0, colour = "grey30"),
        panel.grid.minor = element_blank(),
        plot.background = element_rect(fill = "white", colour = NA),
        plot.title.position = "plot", plot.caption.position = "plot")

dir.create("figures", showWarnings = FALSE)
dir.create("results", showWarnings = FALSE)
ggsave("figures/distribution.svg", p, width = 9, height = 5.5)

# ---- 6. Numbers to report (also saved to a file) ----
res <- data.frame(
  n_earners = n_earners, weighted_median = w_median, unweighted_median = u_median,
  weighted_p10 = p10, weighted_p90 = p90, p90_over_p10 = ratio, n_excluded = n_excluded)
write.csv(res, "results/q2_numbers.csv", row.names = FALSE)
print(res)

# ---- 7. Supporting facts quoted in the written answer (so every number comes from code) ----
w_share_below_u  <- sum(w[x <= u_median]) / sum(w)              # weighted share of earners at or below the unweighted median
u_share_below_u  <- mean(x <= u_median)                         # unweighted share at or below the unweighted median
u_share_at_u     <- mean(x == u_median)                         # share reporting exactly the unweighted median
facts <- data.frame(unweighted_share_at_or_below_unweighted_median = round(100 * u_share_below_u, 1),
                    weighted_share_at_or_below_unweighted_median   = round(100 * w_share_below_u, 1),
                    share_exactly_at_unweighted_median             = round(100 * u_share_at_u, 1),
                    mean_hhweight_above_unweighted_median          = round(mean(w[x > u_median]), 1),
                    mean_hhweight_at_or_below_unweighted_median    = round(mean(w[x <= u_median]), 1),
                    unweighted_median_in_range_only                = median(x[in_range]))
write.csv(facts, "results/q2_supporting_facts.csv", row.names = FALSE)
print(facts)
