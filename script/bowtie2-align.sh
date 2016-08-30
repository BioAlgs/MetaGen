#!/bin/bash
HELPDOC=$( cat <<EOF
Usage:
    bash `basename $0` [options] <ref> <outdir> <reads-dir> <reads-name>
Options:
    -s      Single-end reads
    -p      Paired-ends reads
    -q      For fastq files
    -a      For fasta files
    -h      This help documentation.
EOF
) 

#options
while getopts "sphqa" opt; do
    case $opt in
        s)
            PIRED=false
            ;;
        p)
            PIRED=true
            ;;
        q)
            BOWTIEOPT="-q"
            EXT="fastq"
            ;;
        a)
            BOWTIEOPT="-f"
            EXT="fasta"
            ;;
        h)
            echo "$HELPDOC"
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            echo "$HELPDOC"
            exit 1
            ;;
    esac
done


shift $(($OPTIND - 1)) 


if [ "$#" -ne "4" ]
then
    echo "Invalid number of arguments: 3 needed but $# supplied" >&2
    echo "$HELPDOC"
    exit 1
fi

# module load bowtie2/2.2.7
# module load samtools/1.3

REF=$1
OUTDIR=${2%/}
READSDIR=${3%/}

if [ -d "$OUTDIR" ]; then 
    echo $OUTDIR exists
else
    mkdir $OUTDIR
fi

echo "Begin Alignment:"

if [ "$PIRED" == "true" ];
then
    Q1=$READSDIR/${4}_1.$EXT
    Q2=$READSDIR/${4}_2.$EXT
    folder=$4
    if [ -d "$OUTDIR/$folder" ]; then 
        echo $OUTDIR/$folder exists
    else
        mkdir $OUTDIR/$folder
    fi
    bowtie2 $BOWTIEOPT -x $REF -1 $Q1 -2 $Q2 -S $OUTDIR/$folder/1.sam
    samtools view -Sb  $OUTDIR/$folder/1.sam > $OUTDIR/$folder/1.bam
    samtools sort -o $OUTDIR/$folder/1-sorted.bam $OUTDIR/$folder/1.bam 
    samtools index $OUTDIR/$folder/1-sorted.bam > $OUTDIR/$folder/1-out
    samtools idxstats $OUTDIR/$folder/1-sorted.bam > $OUTDIR/$folder/count.dat
fi

if [ "$PIRED" == "false" ];
then
    Q0=$READSDIR/${4}.$EXT
    folder=$4
    if [ -d "$OUTDIR/$folder" ]; then
        echo $OUTDIR/$folder exists
    else
        mkdir $OUTDIR/$folder
    fi
    bowtie2 $BOWTIEOPT -x $REF -U $Q0 -S $OUTDIR/$folder/1.sam
    samtools view -Sb  $OUTDIR/$folder/1.sam > $OUTDIR/$folder/1.bam
    samtools sort -o $OUTDIR/$folder/1-sorted.bam $OUTDIR/$folder/1.bam
    samtools index $OUTDIR/$folder/1-sorted.bam > $OUTDIR/$folder/1-out
    samtools idxstats $OUTDIR/$folder/1-sorted.bam > $OUTDIR/$folder/count.dat
fi

echo $folder":Alignment Finished."








