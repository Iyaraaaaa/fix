import numpy as np
import tensorflow as tf
import os
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"
if __name__ == "__main__":
    candidates = [
        os.path.join(os.path.dirname(__file__), "..", "assets", "veriframe_model.tflite"),
        os.path.join(os.path.dirname(__file__), "veriframe_model.tflite"),
        os.path.join(os.path.dirname(__file__), "..", "veriframe_app", "assets", "veriframe_model.tflite"),
    ]
    model_path = next((c for c in candidates if os.path.exists(c)), None)
    if model_path:
        i = tf.lite.Interpreter(model_path=model_path)
        i.allocate_tensors()
        ind = i.get_input_details()[0]
        outd = i.get_output_details()[0]
        fake = np.zeros(ind['shape'], dtype=ind['dtype'])
        i.set_tensor(ind['index'], fake)
        i.invoke()
        out = i.get_tensor(outd['index'])[0][0]
        print('SCORE_ZERO:', out)

        fake.fill(255.0)
        i.set_tensor(ind['index'], fake)
        i.invoke()
        out = i.get_tensor(outd['index'])[0][0]
        print('SCORE_WHITE:', out)

