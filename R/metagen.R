###Load dependent packages
library(Rcpp)
library(MASS)
library(foreach)
library(doParallel)
library(mixtools)
library(seqinr)
library(getopt)

###get options
myopt = matrix(c('help','h',0,"logical",
    'work_dir','w',1,"character",
    'metagen_path','m',1,"character",
    'num_cup_cores','n',2,"integer",
    'bic_step','s',2,"integer",
    'bic_min','i',2,"integer",
    'bic_max','a',2,"integer",
    'thred','t',2,"double", 
    'initial_per', 'e', 2, "double",
    'ctg_len_trim','l',2,'integer',
    'plot_bic','p',2,'character',
    'auto_method','o',1,'integer'),byrow=TRUE,ncol=4)

opt=getopt(myopt)

if( !is.null(opt$help)) {
    cat(getopt(myopt, usage=TRUE)); 
    q(status=1);
}

if ( is.null(opt$num_cup_cores ) ) { opt$num_cup_cores = 1 }
if ( is.null(opt$bic_step ) ) { opt$bic_step = 1 }
if ( is.null(opt$bic_min ) ) { opt$bic_min = 2 }
if ( is.null(opt$bic_max ) ) { opt$bic_max = 0 }
if ( is.null(opt$thred ) ) { opt$thred = 0.1 }
if ( is.null(opt$initial_per ) ) { opt$initial_per = 1 }
if ( is.null(opt$ctg_len_trim ) ) { opt$ctg_len_trim = 500 }
if ( is.null(opt$plot_bic ) ) { opt$plot_bic = "F" }
if ( is.null(opt$auto_method ) ) { opt$auto_method = 1 }


work_dir <- opt$work_dir
metagen_path<- opt$metagen_path

bic_step <- opt$bic_step
bic_min <- opt$bic_min
bic_max <- opt$bic_max

thred <- opt$thred
initial_per <- opt$initial_per

num_cpu <- opt$num_cup_cores
ctg_len_trim <- opt$ctg_len_trim

plot_bic<-opt$plot_bic

out_dir = paste(work_dir,"/output",sep="")
source_code = paste(metagen_path,"/src/dist.cpp",sep='')

###Load the c++ code for accelarating the computation
sourceCpp(source_code)

###Load the input data set
rcmm_file=paste(work_dir,"/output/count-map.tsv",sep="")
ctg_file=paste(work_dir,"/ray/Contigs.fasta",sep="")
dmat = as.matrix(read.table(rcmm_file,header=T,check.names = FALSE))
fadat = read.fasta(file = ctg_file)

ctg_name = unlist(lapply(getAnnot(fadat), function(x){strsplit(x," ")[[1]][1]}))

lvec = as.numeric(unlist(lapply(getAnnot(fadat), function(x){strsplit(x," ")[[1]][2]})))

nvec = numeric(ncol(dmat))

reads_sum = read.table(paste(work_dir,"/ray/FilePartition.txt",sep=""), header=F)

##Find the extension of the sequence files
ext_temp = strsplit(as.character(reads_sum[1, 2]),"[.]")[[1]]
ext = ext_temp[length(ext_temp)]
sample_name = colnames(dmat)

if(ext=="fasta"){
    filename = as.character(reads_sum[1, 2])
    t_len = length(strsplit(filename,"/")[[1]])
    filename_s = strsplit(filename,"/")[[1]][t_len]
    if(grepl("_1.fasta",filename_s)){
        for(i in 1:nrow(reads_sum)){
            filename = as.character(reads_sum[i, 2])
            t_len = length(strsplit(filename,"/")[[1]])
            filename_s = strsplit(filename,"/")[[1]][t_len]
            if(grepl("_1.fasta",filename_s)){
                nvec[which(strsplit(filename_s,"_")[[1]][1]==sample_name)] = reads_sum[i,5]
            }else if(grepl("_2.fasta",filename_s)){
                next
            }else if(grepl(".fasta",filename_s)){
                nvec[which(strsplit(filename_s,"[.]")[[1]][1]==sample_name)] = reads_sum[i,5]
            }
        }
    }else{
        nvec = reads_sum[,5]
    }
}

if(ext=="fastq"){
    filename = as.character(reads_sum[1, 2])
    t_len = length(strsplit(filename,"/")[[1]])
    filename_s = strsplit(filename,"/")[[1]][t_len]
    if(grepl("_1.fasta",filename_s)){
        for(i in 1:nrow(reads_sum)){
            filename = as.character(reads_sum[i, 2])
            t_len = length(strsplit(filename,"/")[[1]])
            filename_s = strsplit(filename,"/")[[1]][t_len]
            if(grepl("_1.fastq",filename_s)){
                nvec[which(strsplit(filename_s,"_")[[1]][1]==sample_name)] = reads_sum[i,5]
            }else if(grepl("_2.fastq",filename_s)){
                next
            }else if(grepl(".fastq",filename_s)){
                nvec[which(strsplit(filename_s,"[.]")[[1]][1]==sample_name)] = reads_sum[i,5]
            }
        }
    }else{
        nvec = reads_sum[,5]
    }
}

if(length(which(nvec>0.1))!=length(sample_name)){
    cat("Error: sample_name are not matched.");
    cat(sample_name) 
    q(status=1);
}

##Preparing the data
dmat_rsum = apply(dmat,1,sum)
ind_in = which(lvec>=ctg_len_trim&dmat_rsum>=10)


###Initialize
dmat_rsum_hcluster =  dmat_rsum[ind_in]
hind= which(dmat_rsum_hcluster>quantile(dmat_rsum_hcluster, probs=1-initial_per))
dmat_hcluster = dmat[ind_in,][hind,]

cat("Initializing...\n")
dd <- as.dist(1-rcpp_distance(dmat_hcluster))
cl <- hclust(dd, "ave")
cat("Initialization finished.\n")
cat("Selecting the number of clusters ...\n")

###Cut the hierarchical clustering tree 
try_cut = cutree(cl, h=thred)

###Finding the searching range for number of clusters
if(bic_max>length(unique(try_cut))){
    bic_max = length(unique(try_cut))
}

if(bic_max==0){
    bic_max = length(which(table(try_cut)>1))
}

cat("The searching range for the number of clusters is from",bic_min,"to", bic_max, "with step size", bic_step,"\n")
###Find the best searching range for number of clusters


#####################################################
## BIC for choosing the number of clusters
#####################################################

cluster<-makeCluster(num_cpu)
registerDoParallel(cluster)
#start time
strt<-Sys.time()
 
#loop
dmat_in = dmat[ind_in,]
vncl = seq(bic_min,bic_max,bic_step)
ls<-foreach(ncl_in = vncl,.packages='mixtools') %dopar% {
    tag_sp = as.numeric(names(sort(table(try_cut),decreasing=T)))[1:ncl_in]
    pmat = NULL
    for(j in tag_sp){
        if(sum(try_cut==j)>1){
        temp = apply(dmat_hcluster[which(try_cut==j),],2,sum)
        }else temp = dmat_hcluster[which(try_cut==j),]
        pmat = rbind(pmat,temp)
        # lvec_sp[i]= sum(lvec[which(try_cut==tag_sp[i])])
    }
    pmat = diag(1/apply(pmat,1,sum)) %*% pmat
    multgen = multmixEM(dmat_in, theta =pmat, maxit = 200, epsilon = 1e-03)
    cat("The BIC score for",ncl_in,"clusters finished\n")
    multgen
}

bictime = Sys.time()-strt
stopCluster(cluster)

cat("Running time for selecting number of clusters\n")

lscore= numeric(length(ls))
for(i in 1:length(ls)){
    lscore[i] = ls[[i]]$loglik
}


bic = -2 * lscore + (vncl*ncol(dmat) + vncl) * log(dim(dmat_in)[1])

if(opt$auto_method==1){
    bic.diff = diff(bic)
    bic.ratio = NULL
    for(i in 1:(length(bic.diff)-1)){
        bic.ratio[i] = bic.diff[i+1]/bic.diff[i]
    }

    if(length(which(bic.ratio<0.05))==0){
        opt_num_cluster = max(vncl)
    }else{
        opt_num_cluster = which(bic.ratio<0.05)[1] + 2
    }

    cat("The optimal number of cluster is",opt_num_cluster,"\n")
}else if(opt$auto_method==2){
    bic_ind1 = which(bic > (max(bic) - min(bic))*0.05 + min(bic))
    fit = lm(log(bic[bic_ind1])~vncl[bic_ind1])
    a = fit$coef[2]
    c = fit$coef[1]
    ncl_cut = min(ceiling((min(log(bic)) - c)/a*1.3), vncl[which.min(bic)])
    bic_ind2 = 1:min(which(vncl>=ncl_cut))
    fit = lm(log(bic[bic_ind2])~vncl[bic_ind2])
    a = fit$coef[2]
    c = fit$coef[1]
    opt_num_cluster = round((min(log(bic)) - c)/a)

    cat("The optimal number of cluster is",opt_num_cluster,"\n")
}


##Output the BIC graph
if(plot_bic=="T"){
    pdf(paste(work_dir,"/output/bic.pdf",sep=""))
    plot(vncl, bic,xlab = "Number of clusters", ylab = "BIC")
    dev.off()
}


##Output the cluster label
segs = apply(ls[[which(vncl==opt_num_cluster)]]$posterior,1,function(x){which.max(x)})

write.table(cbind(ctg_name[ind_in], segs), file=paste(work_dir,'/output/segs.txt',sep=""), col.names=F, row.names=F)

cat("Succesffully output the binning result.\n")

##Output the scaled relative abundance matrix
sp_len = numeric(opt_num_cluster)
sp_tr = numeric(opt_num_cluster)
for(i in 1:opt_num_cluster){
    sp_len[i] = sum(lvec[ind_in[which(segs==i)]])
    sp_tr[i] = sum(dmat_rsum[ind_in[which(segs==i)]])
}

sample_name = colnames(dmat)
xx = t(ls[[which(vncl==opt_num_cluster)]]$theta)
xmat = t(diag(10^6/nvec) %*% xx %*% diag(sp_tr/sp_len * 1000))
colnames(xmat) = sample_name


write.table(xmat, file=paste(work_dir,'/output/relative_abundance.txt',sep=""), col.names=T, row.names=F)

cat("Succesffully output the relative abundance matrix.\n")

##Output the relative abundance matrix
rmat = xmat %*% diag(1/apply(xmat,2,sum))
colnames(rmat) = sample_name
write.table(rmat, file=paste(work_dir,'/output/scaled_relative_abundance.txt',sep=""), col.names=T, row.names=F)

cat("Succesffully output the scaled relative abundance matrix.\n")

