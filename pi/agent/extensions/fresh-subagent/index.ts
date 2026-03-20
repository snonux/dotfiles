import { spawn } from "node:child_process";
import type { AgentToolResult, AgentToolResultContent } from "@mariozechner/pi-agent-core";
import type { Message, TextContent } from "@mariozechner/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";

const CHILD_ENV_FLAG = "PI_FRESH_SUBAGENT_CHILD";

interface UsageStats {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: number;
	turns: number;
}

interface FreshSubagentResult {
	prompt: string;
	model?: string;
	cwd: string;
	exitCode: number;
	stopReason?: string;
	errorMessage?: string;
	stderr: string;
	output: string;
	usage: UsageStats;
}

function getProviderScopedModel(ctx: ExtensionContext): string | undefined {
	if (!ctx.model) return undefined;
	return `${ctx.model.provider}/${ctx.model.id}`;
}

function getLastAssistantText(messages: Message[]): string {
	for (let i = messages.length - 1; i >= 0; i--) {
		const message = messages[i];
		if (message.role !== "assistant") continue;
		const text = message.content
			.filter((part): part is TextContent => part.type === "text")
			.map((part) => part.text)
			.join("\n")
			.trim();
		if (text) return text;
	}
	return "";
}

async function runFreshSubagent(
	prompt: string,
	options: {
		cwd: string;
		model?: string;
		tools?: string[];
		signal?: AbortSignal;
		onUpdate?: (partial: AgentToolResult<FreshSubagentResult>) => void;
	},
): Promise<FreshSubagentResult> {
	const args = ["--mode", "json", "-p", "--no-session"];
	if (options.model) args.push("--model", options.model);
	if (options.tools && options.tools.length > 0) args.push("--tools", options.tools.join(","));
	args.push(prompt);

	const result: FreshSubagentResult = {
		prompt,
		model: options.model,
		cwd: options.cwd,
		exitCode: 0,
		stderr: "",
		output: "",
		usage: {
			input: 0,
			output: 0,
			cacheRead: 0,
			cacheWrite: 0,
			cost: 0,
			turns: 0,
		},
	};

	const messages: Message[] = [];

	const emitUpdate = () => {
		options.onUpdate?.({
			content: [{ type: "text", text: result.output || "(running...)" }],
			details: { ...result },
		});
	};

	let wasAborted = false;

	result.exitCode = await new Promise<number>((resolve) => {
		const proc = spawn("pi", args, {
			cwd: options.cwd,
			shell: false,
			stdio: ["ignore", "pipe", "pipe"],
			env: {
				...process.env,
				[CHILD_ENV_FLAG]: "1",
			},
		});

		let buffer = "";

		const processLine = (line: string) => {
			if (!line.trim()) return;

			let event: any;
			try {
				event = JSON.parse(line);
			} catch {
				return;
			}

			if (event.type !== "message_end" || !event.message) return;

			const message = event.message as Message;
			messages.push(message);
			result.output = getLastAssistantText(messages);

			if (message.role === "assistant") {
				result.usage.turns++;
				const usage = message.usage;
				if (usage) {
					result.usage.input += usage.input || 0;
					result.usage.output += usage.output || 0;
					result.usage.cacheRead += usage.cacheRead || 0;
					result.usage.cacheWrite += usage.cacheWrite || 0;
					result.usage.cost += usage.cost?.total || 0;
				}
				if (!result.model && message.model) result.model = message.model;
				if (message.stopReason) result.stopReason = message.stopReason;
				if (message.errorMessage) result.errorMessage = message.errorMessage;
			}

			emitUpdate();
		};

		proc.stdout.on("data", (data) => {
			buffer += data.toString();
			const lines = buffer.split("\n");
			buffer = lines.pop() || "";
			for (const line of lines) processLine(line);
		});

		proc.stderr.on("data", (data) => {
			result.stderr += data.toString();
		});

		proc.on("close", (code) => {
			if (buffer.trim()) processLine(buffer);
			resolve(code ?? 0);
		});

		proc.on("error", () => {
			resolve(1);
		});

		if (options.signal) {
			const killProc = () => {
				wasAborted = true;
				proc.kill("SIGTERM");
				setTimeout(() => {
					if (!proc.killed) proc.kill("SIGKILL");
				}, 5000);
			};

			if (options.signal.aborted) killProc();
			else options.signal.addEventListener("abort", killProc, { once: true });
		}
	});

	if (wasAborted) {
		result.stopReason = "aborted";
		result.errorMessage = "Fresh subagent was aborted";
	}

	result.output ||= getLastAssistantText(messages);
	return result;
}

function renderSubagentSummary(details: FreshSubagentResult, expanded: boolean, theme: any): string {
	const status =
		details.exitCode === 0 && details.stopReason !== "error" && details.stopReason !== "aborted"
			? theme.fg("success", "✓")
			: theme.fg("error", "✗");
	const header = `${status} ${theme.fg("toolTitle", theme.bold("subagent"))}${
		details.model ? theme.fg("muted", ` ${details.model}`) : ""
	}`;

	const lines = [header, theme.fg("muted", `cwd: ${details.cwd}`)];
	if (expanded) {
		lines.push("", theme.fg("muted", "Prompt:"), details.prompt);
		lines.push("", theme.fg("muted", "Result:"), details.output || theme.fg("muted", "(no output)"));
	} else {
		const preview = details.output ? details.output.split("\n").slice(0, 5).join("\n") : "(no output)";
		lines.push("", preview);
	}

	if (details.errorMessage) lines.push("", theme.fg("error", `Error: ${details.errorMessage}`));
	if (details.stderr.trim()) lines.push("", theme.fg("dim", details.stderr.trim()));
	return lines.join("\n");
}

export default function freshSubagentExtension(pi: ExtensionAPI): void {
	if (process.env[CHILD_ENV_FLAG] === "1") return;

	const params = Type.Object({
		prompt: Type.String({ description: "Prompt to run in a fresh-context subagent" }),
		model: Type.Optional(Type.String({ description: "Optional model override. Defaults to the current session model." })),
		cwd: Type.Optional(Type.String({ description: "Working directory for the subagent process" })),
		tools: Type.Optional(Type.Array(Type.String(), { description: "Optional tool allowlist for the subagent process" })),
	});

	pi.registerTool({
		name: "subagent",
		label: "Subagent",
		description: "Spawn a fresh-context subagent with a prompt and return its final answer.",
		promptSnippet: "Delegate a self-contained task to a fresh-context subagent and get its result back",
		promptGuidelines: [
			"Use this tool for any self-contained side task that benefits from a clean context, such as review, research, summarization, or focused implementation checks.",
			"Pass a complete prompt with enough context for the subagent to succeed independently, because it starts with a fresh session.",
		],
		parameters: params,

		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			const details = await runFreshSubagent(params.prompt, {
				cwd: params.cwd ?? ctx.cwd,
				model: params.model ?? getProviderScopedModel(ctx),
				tools: params.tools,
				signal,
				onUpdate,
			});

			const content: AgentToolResultContent[] = [{ type: "text", text: details.output || "(no output)" }];
			const isError = details.exitCode !== 0 || details.stopReason === "error" || details.stopReason === "aborted";

			if (isError) {
				const text = details.errorMessage || details.stderr || details.output || "Fresh subagent failed.";
				return {
					content: [{ type: "text", text }],
					details,
					isError: true,
				};
			}

			return { content, details };
		},

		renderCall(args, theme) {
			const preview = args.prompt.length > 80 ? `${args.prompt.slice(0, 80)}...` : args.prompt;
			return new Text(
				`${theme.fg("toolTitle", theme.bold("subagent"))}\n  ${theme.fg("dim", preview)}`,
				0,
				0,
			);
		},

		renderResult(result, { expanded }, theme) {
			const details = result.details as FreshSubagentResult | undefined;
			if (!details) {
				const text = result.content[0];
				return new Text(text?.type === "text" ? text.text : "(no output)", 0, 0);
			}
			return new Text(renderSubagentSummary(details, expanded, theme), 0, 0);
		},
	});

	pi.registerCommand("subagent", {
		description: "Run a fresh-context subagent with a prompt",
		handler: async (args, ctx) => {
			const prompt = args.trim();
			if (!prompt) {
				ctx.ui.notify("Usage: /subagent <prompt>", "warning");
				return;
			}

			ctx.ui.setStatus("fresh-subagent", ctx.ui.theme.fg("warning", "subagent: running"));

			try {
				const details = await runFreshSubagent(prompt, {
					cwd: ctx.cwd,
					model: getProviderScopedModel(ctx),
				});

				if (!ctx.hasUI) {
					const text = details.output || details.errorMessage || details.stderr || "(no output)";
					if (text) {
						process.stdout.write(`${text}\n`);
					}
					return;
				}

				pi.sendMessage(
					{
						customType: "fresh-subagent-result",
						content: details.output || "(no output)",
						display: true,
						details,
					},
					{ triggerTurn: false },
				);
			} finally {
				ctx.ui.setStatus("fresh-subagent", undefined);
			}
		},
	});

	pi.registerMessageRenderer("fresh-subagent-result", (message, { expanded }, theme) => {
		return new Text(renderSubagentSummary(message.details as FreshSubagentResult, expanded, theme), 0, 0);
	});
}
