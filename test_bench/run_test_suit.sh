path=$1
#Download a given version of minimap2
wget $path
base=`basename $path`
mkdir minimap2
tar -zxvf $base -C minimap2

# Cleanup minimap2 tar
rm $base

dir=`ls minimap2`
echo $dir
minimap2_dir=./minimap2/$dir
cd $minimap2_dir


# Update Makefile. Add -march=native flag for compilation
sed -i 's/CPPFLAGS=/CPPFLAGS= -march=native/g' Makefile 

# Build
make
echo "Minimap2 directory"
ls
cd ../..

# Copy reference sequence to a temporary location
ref=$2
mkdir ref_temp && cp $ref ./ref_temp/
ref_name=`basename $ref`
ref=./ref_temp/$ref_name

# Traverse to mm2-fast directory
cd ..

# Generate lisa_hash index
echo "building index for ONT"
./build_rmi.sh test_bench/$ref map-ont

echo "building index for HiFi" 
./build_rmi.sh test_bench/$ref map-hifi

echo "building index for CLR"
./build_rmi.sh test_bench/$ref map-pb

echo "building index for Assembly"
./build_rmi.sh test_bench/$ref asm5

echo "mm2-fast complation with all optimizations enabled"
make clean && make lhash=1

ls -lh test_bench/ref_temp

cd test_bench

INPUT=`cat $3`

for f in $INPUT
do

	read=`echo $f | cut -d"#" -f1`
	#echo $read
	preset=`echo $f | cut -d"#" -f2`
	#echo $preset
	echo "--------------------------------------------------------------------------------------------"
	echo "     `basename $read` with $preset    "
	echo "--------------------------------------------------------------------------------------------"


	#------------------------ Correctness verification ----------------------------- #

	echo "Running minimap2 with max-chain-skip=1000000"
	$minimap2_dir/minimap2 -ax $preset $ref $read --max-chain-skip=1000000 -t 56 >minimap2_output 2>minimap2_log	
	echo "Running mm2-fast with max-chain-skip=1000000"
	../minimap2 -ax $preset $ref $read --max-chain-skip=1000000 -t 56 >mm2-fast_output 2>mm2-fast_log	

	echo "Comparing diff.."
	ls -lh minimap2_output mm2-fast_output
	correctness=`diff minimap2_output mm2-fast_output | wc -l`
	if [ $correctness == 0 ]
	then
		echo "OUTPUT MATCHED!!"
	else
		echo "OUTPUT INCORRECT: Line difference of $correctness."

	fi
	rm minimap2_output mm2-fast_output	
	rm minimap2_log mm2-fast_log
	
	#------------------------ Performance evaluation ----------------------------- #
	
	echo "Running minimap2 with default setup"
	$minimap2_dir/minimap2 -ax $preset $ref $read -t 56 >minimap2_output 2>minimap2_log	
	echo "Running mm2-fast with default setup -- with lhash, dp_vect, avx512_alignment"
	../minimap2 -ax $preset $ref $read -t 56 >mm2-fast_output 2>mm2-fast_log	
	
	minimap2_index_time=`cat minimap2_log | grep "distinct minimizers" | cut -d":" -f5 | cut -d"*" -f1`

	minimap2_total_time=`cat minimap2_log | grep "Real time" | cut -d" " -f4`

	minimap2_mapping_time=`echo $minimap2_total_time - $minimap2_index_time | bc`
	echo "minimap2: Total time - indexing time = mapping time -- $minimap2_total_time - $minimap2_index_time = $minimap2_mapping_time"

	mm2_fast_mapping_time=`cat mm2-fast_log | grep "Real time" | cut -d" " -f4`
	echo "mm2-fast: mapping time = $mm2_fast_mapping_time"

	speedup=`echo "scale=2; $minimap2_mapping_time / $mm2_fast_mapping_time" | bc`
	echo "Speedup: $speedup"

	rm minimap2_output mm2-fast_output	
	rm minimap2_log mm2-fast_log
done

echo "Cleaning temporary directory for reference sequence"
rm -r ref_temp 
echo "Cleaning extracted minimap2 directory"
rm -r ./minimap2
