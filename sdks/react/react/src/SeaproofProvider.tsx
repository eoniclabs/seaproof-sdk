import { createSeaproof, type SeaproofClient, type SeaproofOptions } from "@seaproof/core";
import { createContext, useContext, useEffect, useMemo, useState, useSyncExternalStore, type ReactNode } from "react";

interface SeaproofContextValue {
  client: SeaproofClient;
  /** Whether the SDK behaves as for testers (from the key's environment, or `mode`). */
  isTesterMode: boolean;
  isOpen: boolean;
  open: () => void;
  close: () => void;
}

const SeaproofContext = createContext<SeaproofContextValue | null>(null);

export interface SeaproofProviderProps extends SeaproofOptions {
  children: ReactNode;
  /** Pass a client instead of options, for example in tests. */
  client?: SeaproofClient;
}

export function SeaproofProvider({ children, client: given, ...options }: SeaproofProviderProps) {
  const [isOpen, setOpen] = useState(false);
  // The client is created once; change the key on the provider to switch projects.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const client = useMemo(() => given ?? createSeaproof(options), [given]);
  useEffect(() => {
    void client.start();
    // A client passed in is owned by the caller.
    return given ? undefined : () => client.dispose();
  }, [client, given]);
  const isTesterMode = useSyncExternalStore(client.subscribe, () => client.isTesterMode, () => false);
  const value = useMemo(
    () => ({ client, isTesterMode, isOpen, open: () => setOpen(true), close: () => setOpen(false) }),
    [client, isTesterMode, isOpen],
  );
  return <SeaproofContext.Provider value={value}>{children}</SeaproofContext.Provider>;
}

/** The Seaproof client and the widget's open state. Use `open()` to start feedback from your own button. */
export function useSeaproof(): SeaproofContextValue {
  const value = useContext(SeaproofContext);
  if (!value) {
    throw new Error("useSeaproof must be used inside <SeaproofProvider>.");
  }
  return value;
}
