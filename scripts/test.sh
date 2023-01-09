#!/usr/bin/env bash
set -e

while getopts d:p:t: flag
do
    case "${flag}" in
        d) directory=${OPTARG};;
        p) profile=${OPTARG};;
        t) test=${OPTARG};;
    esac
done

export FOUNDRY_PROFILE=$profile
echo Using profile: $FOUNDRY_PROFILE

if [ -z "$test" ];
then
    if [ -z "$directory" ];
    then
        forge test --ffi --no-match-path "contracts/invariants/*";
    else
        forge test --ffi --match-path "contracts/$directory/*.t.sol";
    fi
else
    forge test --ffi --match "$test";
fi
