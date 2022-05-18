#
#
# The MIT License
#
#Copyright (c) 2018-     Dana-Farber Cancer Institute
#              2017-2018 Broad Institute, Inc.
#
#Permission is hereby granted, free of charge, to any person obtaining
#a copy of this software and associated documentation files (the
#"Software"), to deal in the Software without restriction, including
#without limitation the rights to use, copy, modify, merge, publish,
#distribute, sublicense, and/or sell copies of the Software, and to
#permit persons to whom the Software is furnished to do so, subject to
#the following conditions:
#
#The above copyright notice and this permission notice shall be
#included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
#BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
#ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
#CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.
#Modified Copyright (C) 2021 Intel Corporation
#   Contacts: Saurabh Kalikar <saurabh.kalikar@intel.com>; 
#	Vasimuddin Md <vasimuddin.md@intel.com>; Sanchit Misra <sanchit.misra@intel.com>; 
#	Chirag Jain <chirag@iisc.ac.in>; Heng Li <hli@jimmy.harvard.edu>
#
ref_data=$1
preset=$2

make clean && make lhash_index=1
touch temp_read.fastq
./minimap2  -ax $2 $1 temp_read.fastq >/dev/null      

kv_file=$1"_"$2"_minimizers_key_value_sorted"  

full_path=`readlink -f $kv_file`

cd ./ext/TAL
make lisa_hash
./build-lisa-hash-index $full_path

rm ../../temp_read.fastq
