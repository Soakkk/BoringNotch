"""Known ad-hoc loader rejection must not be published as a runnable update."""
import json, os, pathlib, subprocess, tempfile
root = pathlib.Path(__file__).resolve().parents[1]
meta = json.loads((root/'Release/personal.json').read_text())
with tempfile.TemporaryDirectory() as folder:
    package = pathlib.Path(folder)
    (package/'release-manifest.json').write_text(json.dumps(dict(meta,source_sha='1'*40,signing='ad-hoc',library_validation_exception=False)))
    result = subprocess.run(['python3',str(root/'Scripts/check-personal-publication.py'),str(package)],env=dict(os.environ,SOURCE_SHA='1'*40),capture_output=True,text=True)
    assert result.returncode != 0 and 'Ad-hoc publication requires the reviewed app-only library-validation exception' in result.stderr, 'Publication did not reject the known ad-hoc loader configuration before processing assets'
print('Publication refuses the confirmed non-launching ad-hoc configuration')
