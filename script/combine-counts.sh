#!/bin/bash
HELPDOC=$( cat <<EOF
Usage:
    bash `basename $0` [options] <work-dir>
Options:
    -s      Single-end reads
    -p      Paired-ends reads
    -h      This help documentation.
EOF
) 


# Parse options
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
echo $#

if [ "$#" -ne "1" ]
then
    echo "Invalid number of arguments: 1 needed but $# supplied" >&2
    echo "$HELPDOC"
    exit 1
fi

ALIGN=${1%/}/map
OUTDIR=${1%/}/output

if [ -d "$OUTDIR" ]; then 
    echo $OUTDIR exists
else
    mkdir $OUTDIR
fi

arr=()
for i in `ls $ALIGN`
do
    arr+=($i)
done

for i in "${arr[@]}"
do  
    echo $ALIGN/$i
    if [ -d "$ALIGN/$i" ] 
    then
        echo $i
        cat $ALIGN/$i/count.dat|awk '{print $3}' > $OUTDIR/$i.temp
    else
        echo File not exist
    fi
done


if [ -f $OUTDIR/count-map.tsv ]; then 
    rm $OUTDIR/count-map.tsv
fi


touch $OUTDIR/count-map.tsv
for i in "${arr[@]}"
do  
    echo -n -e $i'\t' >> $OUTDIR/count-map.tsv
done

sed -i -e '$a\' $OUTDIR/count-map.tsv


EXPANDED=()
for E in "${arr[@]}"; do
    EXPANDED+=($OUTDIR/"${E}.temp")
done
# echo "${EXPANDED[@]}"
paste ${EXPANDED[@]} | column -s $'\t' -t >> $OUTDIR/count-map.tsv


rm $OUTDIR/*.temp
sed -i '$ d' $OUTDIR/count-map.tsv 

