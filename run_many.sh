#!/bin/bash
for i in {1..40}; do 
 time ./zig-out/bin/wv_opt_sim "$(($i * 200))" ./output_gif/$i.png
done
