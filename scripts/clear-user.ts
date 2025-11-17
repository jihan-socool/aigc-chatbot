import "dotenv/config";

import { deleteUserByUsername } from "../lib/db/queries";

async function main() {
  const username = process.argv[2];

  if (!username) {
    console.error("Usage: pnpm clear-user <username>");
    process.exit(1);
  }

  try {
    const result = await deleteUserByUsername({ username });

    if (!result.deletedUser) {
      console.warn(`No user found with username "${username}".`);
    } else {
      console.log(
        `Deleted user "${username}" and ${result.deletedChats} chat(s).`
      );
    }

    process.exit(0);
  } catch (error) {
    console.error("Failed to delete user:", error);
    process.exit(1);
  }
}

main();
