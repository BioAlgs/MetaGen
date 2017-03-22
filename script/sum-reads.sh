#!/bin/bash
HELPDOC=$( cat <<EOF
Usage:
    bash `basename $0` [options] <reads-dir>
Options:
    -s      Single-end reads
    -p      Paired-ends reads
    -h      This help documentation.
EOF
) 

#options
while getopts "sph" opt; do
    case $opt in
        s)
            PIRED=false
            ;;
        p)
            PIRED=true
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


if [ "$#" -ne "2" ]
then
    echo "Invalid number of arguments: 1 needed but $# supplied" >&2
    echo "$HELPDOC"
    exit 1
fi

metagen_data=$1
metagen_work_dir=$2

# metagen_work_dir=./work
# metagen_data=./test_data 
# PIRED=true

echo "filenames_1,filenames_2,readcount_1" > $metagen_work_dir/reads_info.txt

if [ "$PIRED" == "false" ];
then 
    for f in `find $metagen_data/ -maxdepth 1 -type f `; do
        echo $f
        case "$f" in 
        *.fastq) 
            count=$(($(wc -l < $f)/4))
            echo $f,$f,$count >> $metagen_work_dir/reads_info.txt
            ;;
        *.fasta)
            count=`grep -c '>' $f`
            echo -e $f,$f,$count >> $metagen_work_dir/reads_info.txt
            ;;
        esac
    done
fi

if [ "$PIRED" == "true" ];
then 
    for f in `find $metagen_data/*_1.* -maxdepth 1 -type f `; do
        echo $f
        # echo ${f/_1.fastq/_2.fastq}
        case "$f" in 
        *.fastq) 
            if [ -f "${f/_1.fastq/_2.fastq}" ];
            then 
                count=$(($(wc -l < $f)/4))
                echo $f,${f/_1.fastq/_2.fastq},$((count*2)) >> $metagen_work_dir/reads_info.txt
            else
                echo Reads files are not paired.
            fi
            ;;
        *.fasta)
            if [ -f "${f/_1.fasta/_2.fasta}" ];
            then
                count=`grep -c '>' $f`
                echo $f,${f/_1.fasta/_2.fasta},$((count*2)) >> $metagen_work_dir/reads_info.txt
            else
                echo Reads files are not paired.
            fi 
            ;;
        esac
    done
fi

 
