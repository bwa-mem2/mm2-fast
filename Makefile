CFLAGS=		-g -Wall -O2 -Wc++-compat #-Wextra
CPPFLAGS=	-DHAVE_KALLOC #-march=native #-DALIGN_AVX -DPARALLEL_CHAINING #-DMANUAL_PROFILING
COMP_FLAG = -march=native
CHAIN_FLAG = -DPARALLEL_CHAINING
ifneq ($(portable),)
	STATIC_GCC=-static-libgcc -static-libstdc++
endif 
ifeq ($(CXX), icpc)
	CC= icc
else ifeq ($(CXX), g++)
	CC=gcc
endif	

ifeq ($(avx2_compile), 1)
	COMP_FLAG = -mavx2
endif
ifeq ($(arch),sse41)
	CHAIN_FLAG = -DPARALLEL_CHAINING_
	ifeq ($(CXX), icpc)
		COMP_FLAG=-msse4.1
		
	else
		COMP_FLAG=-msse -msse2 -msse3 -mssse3 -msse4.1
	endif
else ifeq ($(arch),sse42)
	CHAIN_FLAG = -DPARALLEL_CHAINING_
	ifeq ($(CXX), icpc)	
		COMP_FLAG=-msse4.2
	else
		COMP_FLAG=-msse -msse2 -msse3 -mssse3 -msse4.1 -msse4.2
	endif
else ifeq ($(arch),avx)
	CHAIN_FLAG = -DPARALLEL_CHAINING_
	ifeq ($(CXX), icpc)
		COMP_FLAG=-mavx ##-xAVX
	else	
		COMP_FLAG=-mavx
	endif
else ifeq ($(arch),avx2)
	ifeq ($(CXX), icpc)
		COMP_FLAG=-march=core-avx2 #-xCORE-AVX2
	else	
		COMP_FLAG=-mavx2
	endif
else ifeq ($(arch),avx512)
	ifeq ($(CXX), icpc)
		COMP_FLAG=-xCORE-AVX512
	else	
		COMP_FLAG=-mavx512bw
	endif
else ifeq ($(arch),native)
	COMP_FLAG=-march=native
else ifneq ($(arch),)
# To provide a different architecture flag like -march=core-avx2.
	COMP_FLAG=$(arch)
else
myall:multi
endif


#CPPFLAGS=	-DHAVE_KALLOC -mavx2 -DALIGN_AVX -DAPPLY_AVX2 -DPARALLEL_CHAINING #-DLISA_HASH -DUINT64 -DVECTORIZE #-DMANUAL_PROFILING
#CPPFLAGS=	-DHAVE_KALLOC -mavx2 -DPARALLEL_CHAINING  #-DMANUAL_PROFILING

# OPT_FLAGS= -DPARALLEL_CHAINING -DALIGN_AVX -DAPPLY_AVX2
OPT_FLAGS=-DALIGN_AVX -DAPPLY_AVX2
OPT_FLAGS+= ${CHAIN_FLAG} 
OPT_FLAGS+=$(COMP_FLAG)
ifeq ($(lhash_index), 1)	
	CPPFLAGS+=	-DLISA_INDEX 
endif
ifeq ($(lhash), 1)	
	OPT_FLAGS+=	-DLISA_HASH -DUINT64 -DVECTORIZE 
endif
ifeq ($(manual_profile), 1)
	CPPFLAGS+= -DMANUAL_PROFILING 
endif

#ifeq ($(use_avx2), 1)
#	OPT_FLAGS+= -DAPPLY_AVX2
#endif

ifeq ($(disable_output), 1)
	CPPFLAGS+= -DDISABLE_OUTPUT
endif

ifeq ($(no_opt),)
	CPPFLAGS+= $(OPT_FLAGS)
endif



#INCLUDES=
#INCLUDES=	-I./ext/TAL_offline/src/LISA-hash #-I./ext/TAL/src/dynamic-programming 
INCLUDES=	-I./ext/TAL/src/LISA-hash -I./ext/TAL/src/chaining -I./ext/TAL/ext/safestringlib/include
OBJS=		kthread.o kalloc.o misc.o bseq.o sketch.o sdust.o options.o index.o \
			lchain.o align.o hit.o seed.o map.o format.o pe.o esterr.o splitidx.o \
			ksw2_ll_sse.o
PROG=		minimap2
PROG_EXTRA=	sdust minimap2-lite
LIBS=		-lm -lz -lpthread -Lext/TAL/ext/safestringlib -lsafestring $(STATIC_GCC)
SAFE_STR_LIB=    ext/TAL/ext/safestringlib/libsafestring.a

CC=$(CXX)
ifeq ($(CC), g++)
	CC=g++ -std=c++11
endif

ifeq ($(arm_neon),) # if arm_neon is not defined
ifeq ($(sse2only),) # if sse2only is not defined
	OBJS+=ksw2_extz2_sse41.o ksw2_extd2_sse41.o ksw2_exts2_sse41.o ksw2_extz2_sse2.o ksw2_extd2_sse2.o ksw2_exts2_sse2.o ksw2_dispatch.o ksw2_extd2_avx.o
else                # if sse2only is defined
	OBJS+=ksw2_extz2_sse.o ksw2_extd2_sse.o ksw2_exts2_sse.o
endif
else				# if arm_neon is defined
	OBJS+=ksw2_extz2_neon.o ksw2_extd2_neon.o ksw2_exts2_neon.o
    INCLUDES+=-Isse2neon
ifeq ($(aarch64),)	#if aarch64 is not defined
	CFLAGS+=-D_FILE_OFFSET_BITS=64 -mfpu=neon -fsigned-char
else				#if aarch64 is defined
	CFLAGS+=-D_FILE_OFFSET_BITS=64 -fsigned-char
endif
endif

ifneq ($(asan),)
	CFLAGS+=-fsanitize=address
	LIBS+=-fsanitize=address
endif

ifneq ($(tsan),)
	CFLAGS+=-fsanitize=thread
	LIBS+=-fsanitize=thread
endif

.PHONY:all extra clean depend
.SUFFIXES:.c .o

.c.o:
		$(CC) -c $(CFLAGS) $(CPPFLAGS) $(INCLUDES) $< -o $@

all:$(PROG)

extra:all $(PROG_EXTRA)

$(PROG):libminimap2.a $(SAFE_STR_LIB) main.o
		$(CC) $(CFLAGS) main.o -o $@ -L. -lminimap2 $(LIBS)

minimap2-lite:example.o libminimap2.a
		$(CC) $(CFLAGS) $< -o $@ -L. -lminimap2 $(LIBS)

libminimap2.a:$(OBJS)
		$(AR) -csru $@ $(OBJS)

sdust:sdust.c kalloc.o kalloc.h kdq.h kvec.h kseq.h ketopt.h sdust.h
		$(CC) -D_SDUST_MAIN $(CFLAGS) $< kalloc.o -o $@ -lz

multi:
		rm -f *.o libminimap2.a; cd ext/TAL/ext/safestringlib/ && $(MAKE) clean;
		$(MAKE) arch=sse41    PROG=minimap2.sse41    CXX=$(CXX) all
		rm -f *.o libminimap2.a; cd ext/TAL/ext/safestringlib/ && $(MAKE) clean;
		$(MAKE) arch=sse42    PROG=minimap2.sse42    CXX=$(CXX) all
		rm -f *.o libminimap2.a; cd ext/TAL/ext/safestringlib/ && $(MAKE) clean;
		$(MAKE) arch=avx    PROG=minimap2.avx    CXX=$(CXX) all
		rm -f *.o libminimap2.a; cd ext/TAL/ext/safestringlib/ && $(MAKE) clean;
		$(MAKE) arch=avx2   PROG=minimap2.avx2     CXX=$(CXX) all
		rm -f *.o libminimap2.a; cd ext/TAL/ext/safestringlib/ && $(MAKE) clean;
		$(MAKE) arch=avx512 PROG=minimap2.avx512bw CXX=$(CXX) all
		$(CXX) -Wall -O3 runsimd.cpp -Iext/TAL/ext/safestringlib/include -Lext/TAL/ext/safestringlib/ -lsafestring $(STATIC_GCC) -o minimap2

# SSE-specific targets on x86/x86_64

ifeq ($(arm_neon),)   # if arm_neon is defined, compile this target with the default setting (i.e. no -msse2)
ksw2_ll_sse.o:ksw2_ll_sse.c ksw2.h kalloc.h
		$(CC) -c $(CFLAGS) -msse2 $(CPPFLAGS) $(INCLUDES) $< -o $@
endif

ksw2_extz2_sse41.o:ksw2_extz2_sse.c ksw2.h kalloc.h
		$(CC) -c $(CFLAGS) -msse4.1 $(CPPFLAGS) -DKSW_CPU_DISPATCH $(INCLUDES) $< -o $@

ksw2_extz2_sse2.o:ksw2_extz2_sse.c ksw2.h kalloc.h
		$(CC) -c $(CFLAGS) -msse2 -mno-sse4.1 $(CPPFLAGS) -DKSW_CPU_DISPATCH -DKSW_SSE2_ONLY $(INCLUDES) $< -o $@

ksw2_extd2_sse41.o:ksw2_extd2_sse.c ksw2.h kalloc.h
		$(CC) -c $(CFLAGS) -msse4.1 $(CPPFLAGS) -DKSW_CPU_DISPATCH $(INCLUDES) $< -o $@

ksw2_extd2_sse2.o:ksw2_extd2_sse.c ksw2.h kalloc.h
		$(CC) -c $(CFLAGS) -msse2 -mno-sse4.1 $(CPPFLAGS) -DKSW_CPU_DISPATCH -DKSW_SSE2_ONLY $(INCLUDES) $< -o $@

ksw2_exts2_sse41.o:ksw2_exts2_sse.c ksw2.h kalloc.h
		$(CC) -c $(CFLAGS) -msse4.1 $(CPPFLAGS) -DKSW_CPU_DISPATCH $(INCLUDES) $< -o $@

ksw2_exts2_sse2.o:ksw2_exts2_sse.c ksw2.h kalloc.h
		$(CC) -c $(CFLAGS) -msse2 -mno-sse4.1 $(CPPFLAGS) -DKSW_CPU_DISPATCH -DKSW_SSE2_ONLY $(INCLUDES) $< -o $@

ksw2_dispatch.o:ksw2_dispatch.c ksw2.h
		$(CC) -c $(CFLAGS) -msse4.1 $(CPPFLAGS) -DKSW_CPU_DISPATCH $(INCLUDES) $< -o $@

# NEON-specific targets on ARM

ksw2_extz2_neon.o:ksw2_extz2_sse.c ksw2.h kalloc.h
		$(CC) -c $(CFLAGS) $(CPPFLAGS) -DKSW_SSE2_ONLY -D__SSE2__ $(INCLUDES) $< -o $@

ksw2_extd2_neon.o:ksw2_extd2_sse.c ksw2.h kalloc.h
		$(CC) -c $(CFLAGS) $(CPPFLAGS) -DKSW_SSE2_ONLY -D__SSE2__ $(INCLUDES) $< -o $@

ksw2_exts2_neon.o:ksw2_exts2_sse.c ksw2.h kalloc.h
		$(CC) -c $(CFLAGS) $(CPPFLAGS) -DKSW_SSE2_ONLY -D__SSE2__ $(INCLUDES) $< -o $@

# other non-file targets
$(SAFE_STR_LIB):
	cd ext/TAL/ext/safestringlib/ && $(MAKE) clean && $(MAKE) CC=gcc directories libsafestring.a

clean:
		rm -fr gmon.out *.o a.out $(PROG) $(PROG_EXTRA) *~ *.a *.dSYM build dist mappy*.so mappy.c python/mappy.c mappy.egg* minimap2.avx  minimap2.avx2  minimap2.avx512bw  minimap2.sse41  minimap2.sse42

depend:
		(LC_ALL=C; export LC_ALL; makedepend -Y -- $(CFLAGS) $(CPPFLAGS) -- *.c)

# DO NOT DELETE

align.o: minimap.h mmpriv.h bseq.h kseq.h ksw2.h kalloc.h
bseq.o: bseq.h kvec.h kalloc.h kseq.h
esterr.o: mmpriv.h minimap.h bseq.h kseq.h
example.o: minimap.h kseq.h
format.o: kalloc.h mmpriv.h minimap.h bseq.h kseq.h
hit.o: mmpriv.h minimap.h bseq.h kseq.h kalloc.h khash.h
index.o: kthread.h bseq.h minimap.h mmpriv.h kseq.h kvec.h kalloc.h khash.h
index.o: ksort.h
kalloc.o: kalloc.h
ksw2_extd2_sse.o: ksw2.h kalloc.h
ksw2_exts2_sse.o: ksw2.h kalloc.h
ksw2_extz2_sse.o: ksw2.h kalloc.h
ksw2_ll_sse.o: ksw2.h kalloc.h
kthread.o: kthread.h
lchain.o: mmpriv.h minimap.h bseq.h kseq.h kalloc.h krmq.h
main.o: bseq.h minimap.h mmpriv.h kseq.h ketopt.h
map.o: kthread.h kvec.h kalloc.h sdust.h mmpriv.h minimap.h bseq.h kseq.h
map.o: khash.h ksort.h
misc.o: mmpriv.h minimap.h bseq.h kseq.h ksort.h
options.o: mmpriv.h minimap.h bseq.h kseq.h
pe.o: mmpriv.h minimap.h bseq.h kseq.h kvec.h kalloc.h ksort.h
sdust.o: kalloc.h kdq.h kvec.h sdust.h
seed.o: mmpriv.h minimap.h bseq.h kseq.h kalloc.h ksort.h
sketch.o: kvec.h kalloc.h mmpriv.h minimap.h bseq.h kseq.h
splitidx.o: mmpriv.h minimap.h bseq.h kseq.h
