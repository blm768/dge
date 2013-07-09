d_src := $(shell find .. -type f -iname '*.d')
docfiles_html := $(patsubst ../%.d,docs/%.html,$(d_src))
docfiles_xml := $(patsubst ../%.d,docs/%.xml,$(d_src))

.PHONY: clean doc_html doc_xml doc_test

doc_html: $(docfiles_html) docs/doc.css
doc_xml: $(docfiles_xml) docs/doc.css docs/doc.xsl

docs/doc.css: ../doc/doc.css
	mkdir -p docs
	cp $< $@

$(docfiles_html): docs/%.html: ../%.d ../doc/html.ddoc
	dmd -I../.. -c -o- -D -Df$@ ../doc/html.ddoc $<

$(docfiles_xml): docs/%.xml: ../%.d ../doc/xml.ddoc
	dmd -I../.. -c -o- -D -Df$@ ../doc/xml.ddoc $<

docs/doc.xsl: ../doc/doc.xsl
	mkdir -p docs
	cp $< $@

doc_test: docs/doc.css docs/doc.xsl
	dmd -I../.. -c -o- -D -Dfdocs/game.xml ../doc/xml.ddoc ../game.d

clean:
	rm -rf docs

