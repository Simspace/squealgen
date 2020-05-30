testTargets := $(patsubst %.dump.sql,%.hs,$(wildcard test/*/Schema.dump.sql))

squealgen: squealgen.sql mksquealgen.sh
	./mksquealgen.sh

install: squealgen
	install squealgen $(prefix)/bin/squealgen

.PHONY: test
test: squealgen $(testTargets)
	 stack test --ghc-options="-fprint-potential-instances"

clean:
	rm $(testTargets)
.PHONY: initdb_exists
initdb_exists:
	which initdb

testwatch: initdb_exists
	while true; do \
		make test; \
		inotifywait -r -e modify -e create -e delete -e move $$(find test -iname '*.hs' | grep -v '#' | grep -v Schema.hs) $$(find . -iname '*\.sql' | grep -v '#' ) squealgen.sql mksquealgen.sh Makefile stack.yaml package.yaml ;\
	done

# todo: bomb out if `schema` doesn't exist.
%.hs: %.dump.sql squealgen

	$(eval db := $(shell pg_tmp))
	@echo $(db)
	$(eval schema := $(shell cat $(@D)/schema))
	$(eval tmp := $(shell mktemp /tmp/squealgen.XXXXXX))
	@echo $(tmp)
	psql -d $(db) < $< && ./squealgen $(db) "$(patsubst test/%,%,$(*D)).$(*F)" $(schema)  > $(tmp)
	./check_schema $(tmp) $@
        # an unprincipled hack: we tag the db connstr in the directory
