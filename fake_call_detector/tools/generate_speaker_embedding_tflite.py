import os
import struct
import random

import flatbuffers
import tflite


MODEL_PATH = os.path.join(
    os.path.dirname(__file__),
    "..",
    "android",
    "app",
    "src",
    "main",
    "assets",
    "speaker_embedding.tflite",
)


def _create_int_vector(builder, values, start_fn):
    start_fn(builder, len(values))
    for v in reversed(values):
        builder.PrependInt32(int(v))
    return builder.EndVector()


def _create_tensor(builder, name, shape, tensor_type, buffer_index):
    name_offset = builder.CreateString(name)
    shape_offset = _create_int_vector(builder, shape, tflite.TensorStartShapeVector)

    tflite.TensorStart(builder)
    tflite.TensorAddName(builder, name_offset)
    tflite.TensorAddShape(builder, shape_offset)
    tflite.TensorAddType(builder, tensor_type)
    tflite.TensorAddBuffer(builder, buffer_index)
    return tflite.TensorEnd(builder)


def _create_buffer(builder, data_bytes):
    if data_bytes:
        tflite.BufferStartDataVector(builder, len(data_bytes))
        for b in reversed(data_bytes):
            builder.PrependByte(b)
        data_offset = builder.EndVector()
    else:
        data_offset = 0

    tflite.BufferStart(builder)
    if data_offset:
        tflite.BufferAddData(builder, data_offset)
    return tflite.BufferEnd(builder)


def main():
    random.seed(42)

    input_size = 13
    embedding_size = 32

    weights = [(random.random() - 0.5) * 0.2 for _ in range(embedding_size * input_size)]
    biases = [0.0 for _ in range(embedding_size)]

    weight_bytes = struct.pack("<" + "f" * len(weights), *weights)
    bias_bytes = struct.pack("<" + "f" * len(biases), *biases)

    builder = flatbuffers.Builder(1024 * 64)

    input_tensor = _create_tensor(builder, "input_mfcc", [1, input_size], tflite.TensorType.FLOAT32, 0)
    weight_tensor = _create_tensor(builder, "fc_weights", [embedding_size, input_size], tflite.TensorType.FLOAT32, 1)
    bias_tensor = _create_tensor(builder, "fc_bias", [embedding_size], tflite.TensorType.FLOAT32, 2)
    output_tensor = _create_tensor(builder, "speaker_embedding", [1, embedding_size], tflite.TensorType.FLOAT32, 3)

    tflite.FullyConnectedOptionsStart(builder)
    tflite.FullyConnectedOptionsAddFusedActivationFunction(
        builder, tflite.ActivationFunctionType.NONE
    )
    tflite.FullyConnectedOptionsAddWeightsFormat(
        builder, tflite.FullyConnectedOptionsWeightsFormat.DEFAULT
    )
    fc_options = tflite.FullyConnectedOptionsEnd(builder)

    op_inputs = _create_int_vector(builder, [0, 1, 2], tflite.OperatorStartInputsVector)
    op_outputs = _create_int_vector(builder, [3], tflite.OperatorStartOutputsVector)

    tflite.OperatorStart(builder)
    tflite.OperatorAddOpcodeIndex(builder, 0)
    tflite.OperatorAddInputs(builder, op_inputs)
    tflite.OperatorAddOutputs(builder, op_outputs)
    tflite.OperatorAddBuiltinOptionsType(builder, tflite.BuiltinOptions.FullyConnectedOptions)
    tflite.OperatorAddBuiltinOptions(builder, fc_options)
    fc_operator = tflite.OperatorEnd(builder)

    tensors_vec = tflite.SubGraphStartTensorsVector(builder, 4)
    builder.PrependUOffsetTRelative(output_tensor)
    builder.PrependUOffsetTRelative(bias_tensor)
    builder.PrependUOffsetTRelative(weight_tensor)
    builder.PrependUOffsetTRelative(input_tensor)
    tensors_vec = builder.EndVector()

    operators_vec = tflite.SubGraphStartOperatorsVector(builder, 1)
    builder.PrependUOffsetTRelative(fc_operator)
    operators_vec = builder.EndVector()

    subgraph_inputs = _create_int_vector(builder, [0], tflite.SubGraphStartInputsVector)
    subgraph_outputs = _create_int_vector(builder, [3], tflite.SubGraphStartOutputsVector)
    subgraph_name = builder.CreateString("speaker_embedder")

    tflite.SubGraphStart(builder)
    tflite.SubGraphAddTensors(builder, tensors_vec)
    tflite.SubGraphAddInputs(builder, subgraph_inputs)
    tflite.SubGraphAddOutputs(builder, subgraph_outputs)
    tflite.SubGraphAddOperators(builder, operators_vec)
    tflite.SubGraphAddName(builder, subgraph_name)
    subgraph = tflite.SubGraphEnd(builder)

    op_code = None
    tflite.OperatorCodeStart(builder)
    tflite.OperatorCodeAddBuiltinCode(builder, tflite.BuiltinOperator.FULLY_CONNECTED)
    tflite.OperatorCodeAddDeprecatedBuiltinCode(builder, tflite.BuiltinOperator.FULLY_CONNECTED)
    tflite.OperatorCodeAddVersion(builder, 1)
    op_code = tflite.OperatorCodeEnd(builder)

    empty_buffer = _create_buffer(builder, b"")
    weight_buffer = _create_buffer(builder, weight_bytes)
    bias_buffer = _create_buffer(builder, bias_bytes)
    output_buffer = _create_buffer(builder, b"")

    opcodes_vec = tflite.ModelStartOperatorCodesVector(builder, 1)
    builder.PrependUOffsetTRelative(op_code)
    opcodes_vec = builder.EndVector()

    subgraphs_vec = tflite.ModelStartSubgraphsVector(builder, 1)
    builder.PrependUOffsetTRelative(subgraph)
    subgraphs_vec = builder.EndVector()

    buffers_vec = tflite.ModelStartBuffersVector(builder, 4)
    builder.PrependUOffsetTRelative(output_buffer)
    builder.PrependUOffsetTRelative(bias_buffer)
    builder.PrependUOffsetTRelative(weight_buffer)
    builder.PrependUOffsetTRelative(empty_buffer)
    buffers_vec = builder.EndVector()

    description = builder.CreateString("On-device lightweight speaker embedding model")

    tflite.ModelStart(builder)
    tflite.ModelAddVersion(builder, 3)
    tflite.ModelAddOperatorCodes(builder, opcodes_vec)
    tflite.ModelAddSubgraphs(builder, subgraphs_vec)
    tflite.ModelAddBuffers(builder, buffers_vec)
    tflite.ModelAddDescription(builder, description)
    model = tflite.ModelEnd(builder)

    builder.Finish(model, file_identifier=b"TFL3")

    os.makedirs(os.path.dirname(MODEL_PATH), exist_ok=True)
    with open(MODEL_PATH, "wb") as f:
        f.write(builder.Output())

    print(f"Generated {MODEL_PATH}")
    print(f"Size: {os.path.getsize(MODEL_PATH)} bytes")


if __name__ == "__main__":
    main()
