#!/bin/sh
#
# Copyright (c) 2015 Jeromy Johnson
# MIT Licensed; see the LICENSE file in this repository.
#

test_description="test the unix files api"

. lib/test-lib.sh

test_init_ipfs

# setup files for testing
test_expect_success "can create some files for testing" '
	FILE1=$(echo foo | ipfs add -q) &&
	FILE2=$(echo bar | ipfs add -q) &&
	FILE3=$(echo baz | ipfs add -q) &&
	mkdir stuff_test &&
	echo cats > stuff_test/a &&
	echo dogs > stuff_test/b &&
	echo giraffes > stuff_test/c &&
	DIR1=$(ipfs add -q stuff_test | tail -n1)
'

verify_path_exists() {
	# simply running ls on a file should be a good 'check'
	ipfs files ls $1
}

verify_dir_contents() {
	dir=$1
	shift
	rm -f expected
	touch expected
	for e in $@
	do
		echo $e >> expected
	done

	test_expect_success "can list dir" '
		ipfs files ls $dir > output
	'

	test_expect_success "dir entries look good" '
		test_sort_cmp output expected
	'
}

test_files_api() {
	test_expect_success "can mkdir in root" '
		ipfs files mkdir /cats
	'

	test_expect_success "directory was created" '
		verify_path_exists /cats
	'

	test_expect_success "directory is empty" '
		verify_dir_contents /cats
	'

	test_expect_success "check root hash" '
		ipfs files stat / | head -n1 > roothash
	'

	test_expect_success "cannot mkdir /" '
		test_expect_code 1 ipfs files mkdir /
	'

	test_expect_success "check root hash was not changed" '
		ipfs files stat / | head -n1 > roothashafter &&
		test_cmp roothash roothashafter
	'

	test_expect_success "can put files into directory" '
		ipfs files cp /ipfs/$FILE1 /cats/file1
	'

	test_expect_success "file shows up in directory" '
		verify_dir_contents /cats file1
	'

	test_expect_success "can read file" '
		ipfs files read /cats/file1 > file1out
	'

	test_expect_success "output looks good" '
		echo foo > expected &&
		test_cmp expected file1out
	'

	test_expect_success "can put another file into root" '
		ipfs files cp /ipfs/$FILE2 /file2
	'

	test_expect_success "file shows up in root" '
		verify_dir_contents / file2 cats
	'

	test_expect_success "can read file" '
		ipfs files read /file2 > file2out
	'

	test_expect_success "output looks good" '
		echo bar > expected &&
		test_cmp expected file2out
	'

	test_expect_success "can make deep directory" '
		ipfs files mkdir -p /cats/this/is/a/dir
	'

	test_expect_success "directory was created correctly" '
		verify_path_exists /cats/this/is/a/dir &&
		verify_dir_contents /cats this file1 &&
		verify_dir_contents /cats/this is &&
		verify_dir_contents /cats/this/is a &&
		verify_dir_contents /cats/this/is/a dir &&
		verify_dir_contents /cats/this/is/a/dir
	'

	test_expect_success "can copy file into new dir" '
		ipfs files cp /ipfs/$FILE3 /cats/this/is/a/dir/file3
	'

	test_expect_success "can read file" '
		ipfs files read /cats/this/is/a/dir/file3 > output
	'

	test_expect_success "output looks good" '
		echo baz > expected &&
		test_cmp expected output
	'

	test_expect_success "file shows up in dir" '
		verify_dir_contents /cats/this/is/a/dir file3
	'

	test_expect_success "can remove file" '
		ipfs files rm /cats/this/is/a/dir/file3
	'

	test_expect_success "file no longer appears" '
		verify_dir_contents /cats/this/is/a/dir
	'

	test_expect_success "can remove dir" '
		ipfs files rm -r /cats/this/is/a/dir
	'

	test_expect_success "dir no longer appears" '
		verify_dir_contents /cats/this/is/a
	'

	test_expect_success "can remove file from root" '
		ipfs files rm /file2
	'

	test_expect_success "file no longer appears" '
		verify_dir_contents / cats
	'

	test_expect_success "check root hash" '
		ipfs files stat / | head -n1 > roothash
	'

	test_expect_success "cannot remove root" '
		test_expect_code 1 ipfs files rm -r /
	'

	test_expect_success "check root hash was not changed" '
		ipfs files stat / | head -n1 > roothashafter &&
		test_cmp roothash roothashafter
	'

	# test read options

	test_expect_success "read from offset works" '
		ipfs files read -o 1 /cats/file1 > output
	'

	test_expect_success "output looks good" '
		echo oo > expected &&
		test_cmp expected output
	'

	test_expect_success "read with size works" '
		ipfs files read -n 2 /cats/file1 > output
	'

	test_expect_success "output looks good" '
		printf fo > expected &&
		test_cmp expected output
	'

	test_expect_success "cannot read from negative offset" '
		test_expect_code 1 ipfs files read --offset -3 /cats/file1
	'

	test_expect_success "read from offset 0 works" '
		ipfs files read --offset 0 /cats/file1 > output
	'

	test_expect_success "output looks good" '
		echo foo > expected &&
		test_cmp expected output
	'

	test_expect_success "read last byte works" '
		ipfs files read --offset 2 /cats/file1 > output
	'

	test_expect_success "output looks good" '
		echo o > expected &&
		test_cmp expected output
	'

	test_expect_success "offset past end of file fails" '
		test_expect_code 1 ipfs files read --offset 5 /cats/file1
	'

	test_expect_success "cannot read negative count bytes" '
		test_expect_code 1 ipfs read --count -1 /cats/file1
	'

	test_expect_success "reading zero bytes prints nothing" '
		ipfs files read --count 0 /cats/file1 > output
	'

	test_expect_success "output looks good" '
		printf "" > expected &&
		test_cmp expected output
	'

	test_expect_success "count > len(file) prints entire file" '
		ipfs files read --count 200 /cats/file1 > output
	'

	test_expect_success "output looks good" '
		echo foo > expected &&
		test_cmp expected output
	'

	# test write

	test_expect_success "can write file" '
		echo "ipfs rocks" > tmpfile &&
		cat tmpfile | ipfs files write --create /cats/ipfs
	'

	test_expect_success "file was created" '
		verify_dir_contents /cats ipfs file1 this
	'

	test_expect_success "can read file we just wrote" '
		ipfs files read /cats/ipfs > output
	'

	test_expect_success "can write to offset" '
		echo "is super cool" | ipfs files write -o 5 /cats/ipfs
	'

	test_expect_success "file looks correct" '
		echo "ipfs is super cool" > expected &&
		ipfs files read /cats/ipfs > output &&
		test_cmp expected output
	'

	test_expect_success "cant write to negative offset" '
		ipfs files stat /cats/ipfs | head -n1 > filehash &&
		test_expect_code 1 ipfs files write --offset -1 /cats/ipfs < output
	'

	test_expect_success "verify file was not changed" '
		ipfs files stat /cats/ipfs | head -n1 > afterhash &&
		test_cmp filehash afterhash
	'

	test_expect_success "write new file for testing" '
		echo foobar | ipfs files write --create /fun
	'

	test_expect_success "write to offset past end works" '
		echo blah | ipfs files write --offset 50 /fun
	'

	test_expect_success "can read file" '
		ipfs files read /fun > sparse_output
	'

	test_expect_success "output looks good" '
		echo foobar > sparse_expected &&
		echo blah | dd of=sparse_expected bs=50 seek=1 &&
		test_cmp sparse_expected sparse_output
	'

	test_expect_success "cleanup" '
		ipfs files rm /fun
	'

	test_expect_success "cannot write to directory" '
		ipfs files stat /cats | head -n1 > dirhash &&
		test_expect_code 1 ipfs files write /cats < output
	'

	test_expect_success "verify dir was not changed" '
		ipfs files stat /cats | head -n1 > afterdirhash &&
		test_cmp dirhash afterdirhash
	'

	test_expect_success "cannot write to nonexistant path" '
		test_expect_code 1 ipfs files write /cats/bar/ < output
	'

	test_expect_success "no new paths were created" '
		verify_dir_contents /cats file1 ipfs this
	'

	test_expect_success "write 'no-flush' succeeds" '
		echo "testing" | ipfs files write -f=false -e /cats/walrus
	'

	test_expect_success "root hash not bubbled up yet" '
		test -z "$ONLINE" ||
		(ipfs refs local > refsout &&
		test_expect_code 1 grep QmcwKfTMCT7AaeiD92hWjnZn9b6eh9NxnhfSzN5x2vnDpt refsout)
	'

	test_expect_success "changes bubbled up to root on inspection" '
		ipfs files stat / | head -n1 > root_hash
	'

	test_expect_success "root hash looks good" '
		echo "QmcwKfTMCT7AaeiD92hWjnZn9b6eh9NxnhfSzN5x2vnDpt" > root_hash_exp &&
		test_cmp root_hash_exp root_hash
	'

	# test mv
	test_expect_success "can mv dir" '
		ipfs files mv /cats/this/is /cats/
	'

	test_expect_success "mv worked" '
		verify_dir_contents /cats file1 ipfs this is walrus &&
		verify_dir_contents /cats/this
	'

	test_expect_success "cleanup, remove 'cats'" '
		ipfs files rm -r /cats
	'

	test_expect_success "cleanup looks good" '
		verify_dir_contents /
	'

	# test flush flags
	test_expect_success "mkdir --flush works" '
		ipfs files mkdir --flush --parents /flushed/deep
	'

	test_expect_success "mkdir --flush works a second time" '
		ipfs files mkdir --flush --parents /flushed/deep
	'

	test_expect_success "dir looks right" '
		verify_dir_contents / flushed
	'

	test_expect_success "child dir looks right" '
		verify_dir_contents /flushed deep
	'

	test_expect_success "cleanup" '
		ipfs files rm -r /flushed
	'

	test_expect_success "child dir looks right" '
		verify_dir_contents /
	'
}

# test offline and online
test_files_api

test_expect_success "clean up objects from previous test run" '
	ipfs repo gc
'

test_launch_ipfs_daemon

ONLINE=1 # set online flag so tests can easily tell
test_files_api
test_kill_ipfs_daemon
test_done
