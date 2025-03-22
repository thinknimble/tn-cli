# /// script
# requires-python = ">=3.12"
# dependencies = ["ollama", "pydantic==2.10.6", "pydantic_ai==0.0.43"]
# ///

import asyncio
import argparse
from pydantic_ai.models.openai import OpenAIModel
from pydantic_ai import Agent
from pydantic_ai.messages import (
    FinalResultEvent,
    FunctionToolCallEvent,
    FunctionToolResultEvent,
    PartDeltaEvent,
    PartStartEvent,
    TextPartDelta,
    ToolCallPartDelta,
)
from pydantic_ai.tools import RunContext

# Argument parsing
parser = argparse.ArgumentParser(description="Args for your call")
parser.add_argument("message", help="Message to process")
parser.add_argument("--api_url", type=str, help="Ollama API URL")
parser.add_argument("--model", type=str, default="qwen2.5-coder:7b", help="Ollama model")
args = parser.parse_args()

model = None
api_url = None


# first try to read the config file, if it exists
def open_file_or_warn(filename):
    try:
        with open(filename, "r") as f:
            return f.read()
    except FileNotFoundError:
        print(f"Warning: {filename} not found")
        return ""

config = open_file_or_warn("~/.tn/.config")

for line in config.splitlines():
    if line.startswith("OLLAMA_API_URL"):
        api_url = line.split("=")[1].strip()
    elif line.startswith("OLLAMA_MODEL"):
        model = line.split("=")[1].strip()

# cli args always override config file
model = args.model if args.model else model if model else "llama3.3"
api_url = args.api_url if args.api_url else api_url if api_url else "http://localhost:11434"
if api_url.endswith("/"):
    api_url = api_url[:-1]

print(args.api_url, api_url, args.model, model)


OLLAMA_MODEL = OpenAIModel(model_name=model, base_url=api_url + "/v1")

agent = Agent(model=OLLAMA_MODEL, system_prompt="You are a helpful assistant")

output_messages = []

async def main():
    async with agent.iter(args.message) as run:
        async for node in run:
            if Agent.is_user_prompt_node(node):
                # A user prompt node => The user has provided input
                output_messages.append(f'=== UserPromptNode: {node.user_prompt} ===')
                print(node.user_prompt)
                print("\n")
            elif Agent.is_model_request_node(node):
                # A model request node => We can stream tokens from the model's request
                output_messages.append(
                    '=== ModelRequestNode: streaming partial request tokens ==='
                )
                async with node.stream(run.ctx) as request_stream:
                    async for event in request_stream:
                        if isinstance(event, PartStartEvent):
                            output_messages.append(
                                f'[Request] Starting part {event.index}: {event.part!r}'
                            )
                            print(event.part.content, end='', flush=True)
                            
                        elif isinstance(event, PartDeltaEvent):
                            if isinstance(event.delta, TextPartDelta):
                                output_messages.append(
                                    f'[Request] Part {event.index} text delta: {event.delta.content_delta!r}'
                                )
                                print(event.delta.content_delta, end='', flush=True)
                            elif isinstance(event.delta, ToolCallPartDelta):
                                output_messages.append(
                                    f'[Request] Part {event.index} args_delta={event.delta.args_delta}'
                                )
                                
                        elif isinstance(event, FinalResultEvent):
                            output_messages.append(
                                f'[Result] The model produced a final result (tool_name={event.tool_name})'
                            )
                            
            elif Agent.is_call_tools_node(node):
                # A handle-response node => The model returned some data, potentially calls a tool
                output_messages.append(
                    '=== CallToolsNode: streaming partial response & tool usage ==='
                )
                async with node.stream(run.ctx) as handle_stream:
                    async for event in handle_stream:
                        if isinstance(event, FunctionToolCallEvent):
                            output_messages.append(
                                f'[Tools] The LLM calls tool={event.part.tool_name!r} with args={event.part.args} (tool_call_id={event.part.tool_call_id!r})'
                            )
                        elif isinstance(event, FunctionToolResultEvent):
                            output_messages.append(
                                f'[Tools] Tool call {event.tool_call_id!r} returned => {event.result.content}'
                            )
            elif Agent.is_end_node(node):
                assert run.result.data == node.data.data
                # Once an End node is reached, the agent run is complete
                output_messages.append(f'=== Final Agent Output: {run.result.data} ===')


if __name__ == "__main__":
    asyncio.run(main())
    # print(output_messages)