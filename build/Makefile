d_src := $(shell find .. -type f -iname '*.d')
docfiles_html := $(patsubst ../%.d,docs/%.html,$(d_src))

.PHONY: clean doc_html

doc_html: $(docfiles_html)

$(docfiles_html): docs/%.html: ../%.d
	dmd -I../.. -c -o- -D -Dd$(dir $@) $<

clean:
	rm -rf docs

