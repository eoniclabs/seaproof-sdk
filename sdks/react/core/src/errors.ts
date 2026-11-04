/** Where every API error code is explained, with how to fix it. */
export const ERROR_REFERENCE_URL = "https://seaproof.io/docs/errors";

/** A failed call to the Seaproof API. `code` is the API's stable error code, e.g. `feedback.description_invalid`. */
export class SeaproofError extends Error {
  readonly status: number;
  readonly code: string | undefined;
  /** The code's entry in the error reference: what went wrong and how to fix it. */
  readonly helpUrl: string | undefined;

  constructor(status: number, code: string | undefined, message: string, helpUrl?: string) {
    super(message);
    this.name = "SeaproofError";
    this.status = status;
    this.code = code;
    this.helpUrl = helpUrl ?? (code ? `${ERROR_REFERENCE_URL}#${code}` : undefined);
  }

  static async fromResponse(response: Response): Promise<SeaproofError> {
    let code: string | undefined;
    let help: string | undefined;
    let message = `Seaproof request failed with ${response.status}`;
    try {
      const problem = (await response.json()) as { code?: string; title?: string; detail?: string; type?: string };
      code = problem.code;
      message = problem.detail ?? problem.title ?? message;
      if (problem.type?.startsWith(ERROR_REFERENCE_URL)) help = problem.type;
    } catch {
      // Not a Problem Details body; keep the generic message.
    }
    return new SeaproofError(response.status, code, message, help);
  }
}

/** For the developer console: the message, the code and where to read how to fix it. */
export function describeError(error: unknown): string {
  if (error instanceof SeaproofError) {
    return `${error.message}${error.code ? ` (${error.code})` : ""}${error.helpUrl ? `. How to fix: ${error.helpUrl}` : ""}`;
  }
  return error instanceof Error ? error.message : String(error);
}
