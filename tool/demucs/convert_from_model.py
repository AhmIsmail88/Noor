"""Write demucs.cpp's ggml weights for htdemucs (4 sources).

Same output as src/scripts/convert-pth-to-ggml.py, but the tensors come from
the model Demucs itself loaded (get_model), instead of loading the
checkpoint file a second time. Demucs stores weights as float16 and
demucs.cpp reads Eigen::half, so tensors are cast to half here.
"""
import struct
import sys
from pathlib import Path

import torch
from demucs.pretrained import get_model

dest = Path(sys.argv[1])
dest.mkdir(parents=True, exist_ok=True)

model = get_model("htdemucs")
if hasattr(model, "models"):  # a BagOfModels with one model
    model = model.models[0]
model.eval()

out = dest / "ggml-model-htdemucs-4s-f16.bin"
with out.open("wb") as fout:
    fout.write(struct.pack("i", 0x646D6334))  # "dmc4"
    count = 0
    for name, tensor in model.state_dict().items():
        data = tensor.detach().to(torch.float16).squeeze().numpy()
        encoded = name.encode("utf-8")
        fout.write(struct.pack("ii", len(data.shape), len(encoded)))
        for size in data.shape:
            fout.write(struct.pack("i", size))
        fout.write(encoded)
        data.tofile(fout)
        count += 1
print(f"wrote {count} tensors to {out}")
