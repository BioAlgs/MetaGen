


packages <- c("Rcpp", "MASS", "mixtools", "doParallel", "foreach",
"seqinr","getopt")
for(i in 1:length(packages)){
if(packages[i] %in% installed.packages()[, "Package"]){
next
}else{
install.packages(packages[i], dependencies=TRUE,repo="https://cran.rstudio.com")
}
}

