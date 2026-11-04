import { useSeaproof } from "@seaproof/react";
import { useState } from "react";

export function App() {
  const seaproof = useSeaproof();
  const [count, setCount] = useState(0);

  return (
    <main style={{ fontFamily: "system-ui, sans-serif", maxWidth: 560, margin: "48px auto", padding: "0 16px" }}>
      <h1>Seaproof example</h1>
      <p>
        Press <strong>Feedback</strong> in the corner, or the button below, and send a report. It
        arrives in your project's inbox with a screenshot and the console and network entries.
      </p>

      <button type="button" onClick={() => setCount((c) => c + 1)}>
        Clicked {count} times
      </button>{" "}
      <button type="button" onClick={() => console.error("Something broke on purpose")}>
        Log an error
      </button>{" "}
      <button type="button" onClick={() => seaproof.open()}>
        Send feedback
      </button>

      <h2>Masked from screenshots</h2>
      <p data-seaproof-mask>Card ending 4242, Jane Doe, jane@example.com</p>
    </main>
  );
}
