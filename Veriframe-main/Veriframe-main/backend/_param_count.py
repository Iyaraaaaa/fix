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
    details = interp.get_tensor_details()

    total_params = 0
    weight_tensors = 0
    for d in details:
        shape = d['shape']
        if len(shape) > 0 and d['dtype'] == np.float32:
            sz = int(np.prod(shape))
            # Only count non-activation tensors (small last dim or weight-like shapes)
            # Use all float32 tensors except input/output
            if d['index'] not in [ind['index'], outd['index']]:
                total_params += sz
                weight_tensors += 1

    print(f'=== {p} ===')
    print(f'Input:  shape={ind["shape"]} dtype={ind["dtype"]}')
    print(f'Output: shape={outd["shape"]} dtype={outd["dtype"]}')
    print(f'Total tensors: {len(details)}')
    print(f'Total float32 tensor elements (all, incl activations): {total_params:,}')

    # Proper weight-only count: filter by name patterns
    weight_params = 0
    for d in details:
        name_str = d['name']
        shape = d['shape']
        if len(shape) == 0:
            continue
        # Weights/biases: kernel, bias, gamma, beta, moving_mean, moving_variance
        is_weight = any(k in name_str for k in ['kernel', 'bias', 'gamma', 'beta', 'moving_mean', 'moving_variance', 'depthwise'])
        if is_weight and d['dtype'] == np.float32:
            weight_params += int(np.prod(shape))

    print(f'Estimated trainable parameters (weight tensors only): {weight_params:,}')
    print()
