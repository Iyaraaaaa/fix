import numpy as np
import tensorflow as tf
import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'

for name in ['veriframe_model.tflite', 'Image.tflite']:
    p = name if os.path.exists(name) else os.path.join('assets', name)
    interp = tf.lite.Interpreter(model_path=p)
    interp.allocate_tensors()
    ind = interp.get_input_details()[0]
    outd = interp.get_output_details()[0]
    print(f'=== {p} ===')
    print(f'Input: shape={ind["shape"]} dtype={ind["dtype"]}')
    print(f'Output: shape={outd["shape"]} dtype={outd["dtype"]}')
    details = interp.get_tensor_details()
    print(f'Total tensors: {len(details)}')
    print('Last 8 tensors:')
    for d in details[-8:]:
        print(f'  [{d["index"]}] {d["name"]!r} shape={d["shape"]} dtype={d["dtype"]}')
    print()

# Parameter count estimation
import os
for name in ['veriframe_model.tflite', 'Image.tflite']:
    p = name if os.path.exists(name) else os.path.join('assets', name)
    interp2 = tf.lite.Interpreter(model_path=p)
    interp2.allocate_tensors()
    total = 0
    for d in interp2.get_tensor_details():
        t = interp2.get_tensor(d['index'])
        import numpy as np
        if t.dtype == np.float32:
            total += t.size
    print(f'{p} - approx trainable float32 params: {total:,}')
