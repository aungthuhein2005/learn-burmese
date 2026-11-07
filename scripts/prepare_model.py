"""Download the Myanmar handwriting model from Hugging Face and save it as a
single-file float32 ONNX model for the iOS app bundle, with the exported
Loop/as_strided block removed.

float32 on purpose: on iPhone (arm64) ONNX Runtime 1.20's float16 CPU paths
were ~20x slower and crashed (EXC_BAD_ACCESS) during reference preparation.

Usage:  python scripts/prepare_model.py <output_path>
"""
import sys
import urllib.request
from pathlib import Path

import numpy as np
import onnx
import onnxruntime as ort

REPO = "https://huggingface.co/aungthuhein-dev/myanmar-handwriting/resolve/main/"


def download(name: str, dest: Path) -> None:
    if dest.exists():
        return
    print(f"Downloading {name} ...")
    urllib.request.urlretrieve(REPO + name, dest)


def remove_as_strided(graph: onnx.GraphProto) -> None:
    """The PyTorch export turned an `as_strided` after global average pooling
    into a Loop/SequenceInsert/Gather block. Its result equals the pooled tensor
    `mean` ([B, 768, 1, 1]) unchanged, but the Loop breaks fp16 conversion and
    Core ML. Rewire consumers of `as_strided` to `mean` and drop dead nodes."""
    for node in graph.node:
        for i, name in enumerate(node.input):
            if name == "as_strided":
                node.input[i] = "mean"
    outputs = {o.name for o in graph.output}
    while True:
        used = {i for n in graph.node for i in n.input} | outputs
        dead = [n for n in graph.node if not any(o in used for o in n.output)]
        if not dead:
            break
        for n in dead:
            graph.node.remove(n)
    names = {i for n in graph.node for i in n.input}
    for init in [t for t in graph.initializer if t.name not in names]:
        graph.initializer.remove(init)
    assert not any(n.op_type == "Loop" for n in graph.node), "Loop still present"


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "KaGyi/Resources/model.onnx")
    work = Path("build/model_src")
    work.mkdir(parents=True, exist_ok=True)
    download("model.onnx", work / "model.onnx")
    download("model.onnx.data", work / "model.onnx.data")

    model = onnx.load(str(work / "model.onnx"))  # loads external data too
    remove_as_strided(model.graph)
    out.parent.mkdir(parents=True, exist_ok=True)
    onnx.save(model, str(out))   # single file (< 2 GB protobuf limit)
    print(f"Saved {out} ({out.stat().st_size / 1e6:.1f} MB)")

    # Sanity check: the rewired graph must match the original export.
    rng = np.random.default_rng(0)
    x = rng.random((2, 3, 224, 224), dtype=np.float32)
    a = ort.InferenceSession(str(work / "model.onnx")).run(None, {"input": x})[0]
    b = ort.InferenceSession(str(out)).run(None, {"input": x})[0]
    cos = (a * b).sum(1) / (np.linalg.norm(a, axis=1) * np.linalg.norm(b, axis=1))
    print("original vs prepared cosine:", cos)
    if cos.min() < 0.9999:
        sys.exit("prepared model does not match the original")


if __name__ == "__main__":
    main()
