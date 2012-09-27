# load the data and rename columns
comp <- read.csv("data/crsp.csv", header=TRUE)
names(comp) <- tolower(names(comp))
names(comp)[2] <- "permno"
names(comp)[4] <- "year"
stocks <- levels(factor(comp$permno))

# use cusip to remove non-ordinary shares
comp$cusip <- as.character(comp$cusip)
nchar <- nchar(comp$cusip)
comp <- comp[nchar >= 8,]
comp$cusip[nchar == 8] <- paste("0", comp$cusip[nchar == 8], sep="")
comp$cic <- substr(comp$cusip, 7, 8)
comp <- comp[comp$cic == "10" | comp$cic == "11",]
comp$cusip <- NULL

# remove financial stocks based on SIC
comp$sich <- ifelse(is.na(comp$sich), comp$sic, comp$sich)
comp <- comp[comp$sich < 6000 | comp$sich > 6999,]
comp$sic <- NULL
comp$sich <- NULL

# remove duplicate entries
comp <- comp[!duplicated(comp[, c("year", "permno")]),]

# remove any characters from key values
destring <- function(x, columns=names(crsp)) {
    tmp <- x
    tmp[, columns] <- suppressWarnings(lapply(lapply(x[, columns], as.character), as.numeric))
    return (tmp)
}
comp <- destring(comp, c("act", "at", "che", "csho", "dlc", "dp", "dvp", "ib", "lct", "lt",
                         "pstkl", "pstkrv", "txdi", "txditc", "upstk", "adjex_f"))

# reduces columns of a matrix into a single vector, choosing the first value of each row
# from left to right that is non-zero and not missing
best.available <- function(x) {
    if (is.null(dim(x))) {
        return (ifelse(is.na(x), 0, x))
    } else {
        best <- apply(x, MARGIN=1, FUN=best.available.helper)
        return (best)
    }
}

# helper function for best.available
best.available.helper <- function(row) {
    best <- which(row != 0)[1]
    if (is.na(best))
        return (0)
    else
        return (row[best])
}

# calculate book equity
comp$be <- comp$at - comp$lt + best.available(comp$txditc) - best.available(cbind(comp$pstkl, comp$pstkrv, comp$upstk))

# calculate profitability (ROA)
comp$roa <- (comp$ib - best.available(comp$dvp) + best.available(comp$txdi)) / comp$at

for (s in stocks) {
    stock <- comp$permno == s # row indices of stock
    len <- length(comp[stock,1]) # number of periods for this stock
    trim <- len - 1 # used to trim the last entry (since we are dealing with y-1 and y-2)
    
    # calculate asset growth
    at <- comp$at[stock]
    comp$agr[stock][3:len] <- (diff(at) / at[-len])[-trim]
    
    # calculate net stock issues
    shares <- comp$csho[stock] * comp$adjex_f[stock]
    comp$issues[stock][3:len] <- (shares[-1] / shares[-len])[-trim]
    
    # calculate accruals
    dp <- comp$dp[stock]
    comp$accruals[stock][3:len] <- (
        diff(comp$act[stock]) - 
        diff(comp$lct[stock]) - 
        diff(comp$che[stock]) + 
        diff(comp$dlc[stock]) - 
        dp[-1] / at[-len])[-trim]
    
    # calculate book to market equity
    
}