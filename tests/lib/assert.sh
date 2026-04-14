#!/bin/bash

fail() {
    echo "[FAIL] $*" >&2
    return 1
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="${3:-expected '$expected', got '$actual'}"
    [ "$expected" = "$actual" ] || fail "$message"
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-expected output to contain '$needle'}"
    case "$haystack" in
        *"$needle"*) ;;
        *) fail "$message" ;;
    esac
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-expected output not to contain '$needle'}"
    case "$haystack" in
        *"$needle"*) fail "$message" ;;
        *) ;;
    esac
}
