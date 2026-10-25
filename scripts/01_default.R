# 01_default.R -- Q4: the DEFAULT figure (R defaults, nothing added)
# Run from the repository root:  Rscript scripts/01_default.R

library(ggplot2)
library(svglite)

# ---- 1. Read the two local CSV files (no internet needed) ----
person <- read.csv("data/pslm_person_subset.csv")
hh     <- read.csv("data/pslm_hh_subset.csv")

# ---- 2. Attach weight, province and area from the household file ----
hh_small <- hh[, c("hhid", "hhweight", "prov_code", "urban_rural")]
d <- merge(person, hh_small, by = "hhid")

# ---- 3. My variant: registration FA24-BEDS-104 -> last two digits 04 -> 4 = 0*8 + 4 -> variant 4 = Khyber Pakhtunkhwa (KP) rural
#         Earners = age 15-64 and earn_annual > 0
# which() drops rows where earn_annual is NA (missing) -- NA > 0 is NA, not FALSE
earners <- d[which(d$prov_code == 1 & d$urban_rural == 1 &
                   d$age >= 15 & d$age <= 64 & d$earn_annual > 0), ]

# ---- 4. The default figure: exactly ggplot(data, aes(x, y)) + geom_point() ----
p <- ggplot(earners, aes(age, earn_annual)) + geom_point()

dir.create("figures", showWarnings = FALSE)
ggsave("figures/default.svg", p, width = 7, height = 5)
cat("Saved figures/default.svg with", nrow(earners), "earners\n")
