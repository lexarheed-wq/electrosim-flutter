from pathlib import Path
root=Path(__file__).resolve().parents[1]
pre=(root/'tools/f15_platform_preflight.sh').read_text()
host=(root/'tools/f15_qualify_current_host.sh').read_text()
target=(root/'tools/f15_qualify_target.sh').read_text()
checks={
 'preflight-exists': 'F15_TARGET_UNAVAILABLE' in pre and 'F15_TARGET_AVAILABLE' in pre,
 'ios-sdk-probe': 'xcrun --sdk iphoneos --show-sdk-path' in pre,
 'qualify-target-runs-preflight': 'f15_platform_preflight.sh' in target,
 'current-host-graceful-unavailable': 'if [ "$rc" -eq 3 ]' in host,
 'no-fake-ios-pass': 'F15_TARGET_QUALIFICATION_PASS ios' not in host,
}
bad=[k for k,v in checks.items() if not v]
if bad:
    raise SystemExit('F15_PLATFORM_CONTRACT_FAIL '+','.join(bad))
print(f'F15_PLATFORM_CONTRACT_PASS {len(checks)}/{len(checks)}')
