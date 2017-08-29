# MetaGen
A test data with 6 microbial species is available at https://figshare.com/articles/test-data_zip/3491951

The following is a small example. For the more detailed instruction, please see the software manual. Before running this example, please install all dependent software and packages listed in the manual.


## Example 

Download MetaGen and testing data set.
```shellscript
mkdir example
cd example
git clone https://github.com/BioAlgs/MetaGen
wget https://ndownloader.figshare.com/files/5523092
unzip 5523092

```

Set the environment variables for the path of MetaGen, testing data set and work directory as
```shellscript
mkdir work
metagen=[Directory of example]/MetaGen
metagen_data=[Directory of example]/test_data 
metagen_work_dir=[Directory of example]/work
```

Run assembly using Ray assembler:
```shellscript
cd $metagen_data 
mpiexec -n 10 Ray -k 31 -detect-sequence-files ./ -o \ $metagen_work_dir/ray
```

Build the bowtie index:
```shellscript
mkdir $metagen_work_dir/contigs
cp $metagen_work_dir/ray/Contigs.fasta $metagen_work_dir/contigs
cd $metagen_work_dir/contigs
bowtie2-build Contigs.fasta ./contigs-ref
```

Extract the read counts mapping matrix(for single-end reads):
```shellscript
cd ../ 
chmod +x $metagen/script/bowtie2-align.sh 
ls $metagen_data/*.fasta |  gawk '{gsub(/.*[/]|.fasta/, "", $0)} 1'| xargs -P 6 -n 1 $metagen/script/bowtie2-align.sh -s -a $metagen_work_dir/contigs/contigs-ref $metagen_work_dir/map $metagen_data
bash $metagen/script/combine-counts.sh -s $metagen_work_dir
```

Extract the read counts mapping matrix(for paired-end reads):
```shellscript
## do not run for this example
cd ../ 
chmod +x $metagen/script/bowtie2-align.sh 
ls $metagen_data/*_1.fasta |  gawk '{gsub(/.*[/]|_1.fasta/, "", $0)} 1'| xargs -P 6 -n 1 $metagen/script/bowtie2-align.sh -p -a $metagen_work_dir/contigs/contigs-ref $metagen_work_dir/map $metagen_data
bash $metagen/script/combine-counts.sh -s $metagen_work_dir
```

Extract the summary information of each sample:
```shellscript
bash $metagen/script/sum-reads.sh -s $metagen_data $metagen_work_dir
```

Run the statistical deconvolution algorithm to get the binning results and relative-abundance estimation:
```shellscript
Rscript $metagen/R/metagen.R -m $metagen -w $metagen_work_dir
```
Remark: For large number of species, we recommend to set "bic_step"(using "-s" option) to a larger number such as 5 or 10,  "bic_min" (using "-i" option) to "10" or "50" and "auto_method" (using "-o" option) to 2. This will greatly reduce the computational cost.
```shellscript
Do not run
Rscript $metagen/R/metagen.R -m $metagen -w $metagen_work_dir -s 10 -i 10 -o 2
```
