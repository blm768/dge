d_src := $(shell find .. -type f -iname '*.d')
docfiles_html := $(patsubst ../%.d,docs/%.html,$(d_src))

.PHONY: clean doc_html doc_test

doc_html: $(docfiles_html) docs/doc.css

docs/doc.css: ../doc/doc.css
	cp $< $@

$(docfiles_html): docs/%.html: ../%.d ../doc/html.ddoc
	dmd -I../.. -c -o- -D -Dd$(dir $@) ../doc/html.ddoc $<

doc_test: docs/doc.css
	dmd -I../.. -c -o- -D -Dddocs ../doc/html.ddoc ../window.d

clean:
	rm -rf docs

