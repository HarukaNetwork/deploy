check:
	while read -r script; do shellcheck --exclude=SC2045,SC2129,SC2181 $$script; done < files

.PHONY: check
