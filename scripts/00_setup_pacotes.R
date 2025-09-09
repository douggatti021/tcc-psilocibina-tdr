
# Pacotes necessários
pkgs <- c("here","fs","dplyr","readr","tidyr","lubridate","openxlsx","microdatasus","testthat")

to_install <- setdiff(pkgs, rownames(installed.packages()))
if (length(to_install)) install.packages(to_install, dependencies = TRUE)

# Confirmar
sapply(pkgs, function(p) paste(p, "->", require(p, character.only = TRUE)))

