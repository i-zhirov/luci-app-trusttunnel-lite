# Reading the records file: lines of the form "section.option<TAB>value".
# Requires TT_RECORDS with the path to the file. Source with a dot.
#
# The "${TT_RECORDS:?...}" check sits at the START OF EVERY FUNCTION rather
# than as a standalone line at the top level. All four real callers
# (gen-config, gen-lists, fetch-lists, routing) `. records.sh` BEFORE
# assigning TT_RECORDS from their argument — so a top-level check would
# fire on every sourcing, before the caller could set the variable, and
# would break all four generators for nothing. A check inside the functions
# achieves the same goal — an unconfigured TT_RECORDS fails with a clear
# error instead of silently becoming an empty file name on which awk
# quietly reads stdin — but fires at the moment of the actual access, when
# TT_RECORDS must already be set.

tt_list() {
	: "${TT_RECORDS:?TT_RECORDS is not set}"
	awk -F'\t' -v k="$1" '$1 == k { print $2 }' "$TT_RECORDS"
}

tt_get() {
	: "${TT_RECORDS:?TT_RECORDS is not set}"
	_v=$(awk -F'\t' -v k="$1" '$1 == k { print $2; exit }' "$TT_RECORDS")
	if [ -n "$_v" ]; then
		printf '%s\n' "$_v"
	else
		printf '%s\n' "${2-}"
	fi
}

tt_bool() {
	: "${TT_RECORDS:?TT_RECORDS is not set}"
	_v=$(awk -F'\t' -v k="$1" '$1 == k { print $2; exit }' "$TT_RECORDS")
	[ -n "$_v" ] || _v="${2-0}"
	if [ "$_v" = "1" ]; then printf 'true\n'; else printf 'false\n'; fi
}

tt_count() {
	: "${TT_RECORDS:?TT_RECORDS is not set}"
	awk -F'\t' -v k="$1" '$1 == k { n++ } END { print n + 0 }' "$TT_RECORDS"
}
