#!/usr/bin/env Rscript
args <- commandArgs()
infile <- args[6]
target <- as.numeric(args[7])
dataset <- read.csv(infile, header = TRUE)
colClasses = c("numeric", "numeric")
attach(dataset)
linefit  <- lm(y ~ x)
polyfit2 <- lm(y ~ poly(x,2))
polyfit3 <- lm(y ~ poly(x,3))
polyfit4 <- lm(y ~ poly(x,4))
polyfit5 <- lm(y ~ poly(x,5))
#expfit <- lm(log(y) ~ log(x))
predict(linefit, data.frame(x = target))
#predict(expfit, data.frame(x = target))
predict(polyfit2, data.frame(x = target))
