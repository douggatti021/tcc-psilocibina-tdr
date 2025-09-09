.PHONY: setup run clean

setup:
	Rscript scripts/setup.R

run:
	Rscript scripts/pipeline.R

clean:
	rm -f saida_dados/*.csv resultados/*.xlsx
