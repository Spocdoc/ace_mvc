test:
	mocha

watch:
	mocha -w

coverage:
	coffeecoverage lib lib-cov
	MOCHA_COV=1 mocha --reporter html-cov > coverage.html
	open coverage.html
	rm -rf lib-cov

.PHONY: test watch
DEFAULT: test
