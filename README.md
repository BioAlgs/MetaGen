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

Create file to store sample names.
```shellscript
cd ./test_data
rm read_list.txt
for f in *.fasta; do 
   g=$(echo $f |gawk '{gsub(/.*[/]|.fasta/, "", $0)} 1')
   echo -e "$PWD/$g" >> read_list.txt
done
```

###Running MetaGen
Users can run MetaGen using the following command
```shellscript
cd ..
mkdir metagen_work
./MetaGen.sh -a -c ./test_data/ray/Contigs.fasta -o ./metagen_work -s ./test_data/read_list.txt 
```

where -a denotes that the file type is fasta file (-q for fastq file); -c is the option for the path of assembled contigs file; -o is the option for the path of working directory and -s is the option for the file including the list of sample names for the single-end reads (-p for paired-end reads).

More detailed options are listed here
```shellscript
Usage:
    MetaGen.sh [options] -c <contigs> -o <outdir> -p <sample-list>
Options:
	-o      Output directory
	-c      The path to the contigs fasta file
    -s      the list of single-end sample names
    -p      the list of paired-ends sample names
    -q      For fastq files
    -a      For fasta files
######## Options for binning
	-n Number of threads: Specify the number of CPU cores used for parallel computing. When there is a large number of contigs, it is recommended to set multiple CPU cores to accelerate the computation. The default number is 1.
	-l Specify the minimum number of clusters. The default is 2.
	-u Specify the maximum number of clusters. The default is 0, which will let the algorithm sets the maximum number of cluster automatically.
	-e Specify the increment of the number of clusters from bic_min to bic_max. The default is 1.
	-t Specify the threshold for setting the initial value. It is recommended to set this number smaller(0.01-0.1) when the number of samples is less than $10$ and larger (0.1-0.2) when the number of samples is larger than $10$. The default value is set to 0.1.
	-i Specify how many percent contigs are used to set the initial value of the algorithm. The default value is 1, which means that all the contigs is used to find initial value of the algorithm. The number can be set to a smaller one, when there are a very large number of contigs.
	-r Specify the minimum contig length, contigs shorter than this value will not be included. Default is 500.
	-c If the value is "T", output the plot of BIC scores. The default is "F".
	-m The value is "1" for the simple metagenomic community. The value is "2" for the complex metagenomic community.
    -h  This help documentation.
```

Remark: For large number of species, we recommend to set “bic_step”(using “-e” option) to a larger number such as 5 or 10, “bic_min” (using “-l” option) to “10” or “50” and “auto_method” (using “-m” option) to 2. This will greatly reduce the computational cost.




---
###(Old Pipline) 
If users want to MetaGen separately, they can follow the following instructions.
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
