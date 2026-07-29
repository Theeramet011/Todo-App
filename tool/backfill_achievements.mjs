import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const applyChanges = process.argv.includes("--apply");
const projectId = process.env.GOOGLE_CLOUD_PROJECT;

initializeApp({
  credential: applicationDefault(),
  ...(projectId ? { projectId } : {}),
});

const db = getFirestore();
const [usersSnapshot, projectsSnapshot, tasksSnapshot] = await Promise.all([
  db.collection("users").get(),
  db.collection("projects").get(),
  db.collection("tasks").get(),
]);

const projectLeaders = new Map(
  projectsSnapshot.docs.map((doc) => {
    const data = doc.data();
    return [doc.id, data.leaderId ?? data.ownerId ?? data.creatorId ?? ""];
  }),
);
const counts = new Map();

function countersFor(userId) {
  if (!counts.has(userId)) {
    counts.set(userId, {
      tasksCompleted: 0,
      groupTasksCompleted: 0,
      memberGroupTasksCompleted: 0,
      leaderGroupTasksCompleted: 0,
    });
  }
  return counts.get(userId);
}

function assigneeIdsFor(data) {
  if (Array.isArray(data.assigneeIds) && data.assigneeIds.length > 0) {
    return data.assigneeIds.filter(Boolean);
  }
  if (data.assigneeId) return [data.assigneeId];
  if (Array.isArray(data.members)) {
    return data.members.map((member) => member?.id).filter(Boolean);
  }
  return [];
}

function isGroupTask(data) {
  return data.type === "group" || Boolean(data.projectId);
}

for (const task of tasksSnapshot.docs) {
  const data = task.data();
  if (data.status !== "completed" || data.isDeleted === true) continue;

  const assigneeIds = assigneeIdsFor(data);
  if (!isGroupTask(data)) {
    const userId = assigneeIds[0] ?? data.creatorId;
    if (userId) countersFor(userId).tasksCompleted += 1;
    continue;
  }

  const leaderId = projectLeaders.get(data.projectId) ?? data.creatorId ?? "";
  if (data.submittedBy && data.submittedBy !== leaderId) {
    const memberCounters = countersFor(data.submittedBy);
    memberCounters.groupTasksCompleted += 1;
    memberCounters.memberGroupTasksCompleted += 1;
  }
  if (leaderId) {
    const leaderCounters = countersFor(leaderId);
    leaderCounters.groupTasksCompleted += 1;
    leaderCounters.leaderGroupTasksCompleted += 1;
  }
}

const thresholds = [
  ["pathfinder", "tasksCompleted", 10],
  ["task_master", "tasksCompleted", 50],
  ["legendary_worker", "tasksCompleted", 100],
  ["spark", "currentStreak", 3],
  ["on_fire", "currentStreak", 7],
  ["unstoppable", "currentStreak", 30],
  ["team_player", "memberGroupTasksCompleted", 5],
  ["squad_captain", "leaderGroupTasksCompleted", 20],
];
const updates = [];

for (const userDoc of usersSnapshot.docs) {
  const data = userDoc.data();
  const counters = countersFor(userDoc.id);
  const progress = {
    ...counters,
    currentStreak: Number(data.currentStreak ?? data.streak ?? 0),
  };
  const unlocked = new Set(
    Array.isArray(data.achievementsUnlocked) ? data.achievementsUnlocked : [],
  );
  unlocked.delete("team_player");
  unlocked.delete("squad_captain");
  for (const [id, field, target] of thresholds) {
    if (progress[field] >= target) unlocked.add(id);
  }
  updates.push({
    ref: userDoc.ref,
    data: {
      ...counters,
      achievementsUnlocked: [...unlocked],
    },
  });
}

console.log(`${applyChanges ? "APPLY" : "DRY RUN"}: ${updates.length} users`);
for (const update of updates) {
  console.log(update.ref.id, update.data);
}

if (!applyChanges) {
  console.log("No writes performed. Re-run with --apply to update Firestore.");
  process.exit(0);
}

for (let index = 0; index < updates.length; index += 450) {
  const batch = db.batch();
  for (const update of updates.slice(index, index + 450)) {
    batch.set(update.ref, update.data, { merge: true });
  }
  await batch.commit();
}

console.log(`Updated ${updates.length} users.`);
