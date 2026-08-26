// ไฟล์นี้เปรียบเสมือนสมองของระบบหลังบ้าน (Cloud Functions)
// ทำหน้าที่คอยตรวจสอบข้อมูล สั่งการ และส่งการแจ้งเตือนไปยังโทรศัพท์ของผู้ใช้งาน
const { HttpsError, onCall } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
if (!admin.apps.length) {
  admin.initializeApp();
}

const FUNCTION_REGION = "asia-southeast1";
const TASK_REMINDER_CHANNEL_ID = "task_reminder_alerts_v3";
const TASK_COMMENT_CHANNEL_ID = "task_comment_alerts_v2";
const IN_APP_NOTIFICATION_CHANNEL_ID = TASK_REMINDER_CHANNEL_ID;
const CLIENT_PUSH_NOTIFICATION_TYPES = new Set([
  "Comment",
  "Group",
  "Submission",
  "Approved",
  "Rejected",
  "FriendRequest",
  "FriendAccepted",
]);

function androidChannelIdForNotificationType(notificationType) {
  return notificationType === "Comment"
    ? TASK_COMMENT_CHANNEL_ID
    : IN_APP_NOTIFICATION_CHANNEL_ID;
}

function androidNotificationPriorityForType(notificationType) {
  return notificationType === "Comment" ? "max" : "max";
}

function isInvalidFcmTokenError(err) {
  const code = asMessageText(err && err.code);
  const message = asMessageText(err && err.message).toLowerCase();
  return code === "messaging/registration-token-not-registered" ||
    code === "messaging/invalid-registration-token" ||
    message.includes("requested entity was not found");
}

function setRecipientRole(recipientRoles, userId, role) {
  if (typeof userId !== "string" || userId.trim().length === 0) return;

  const normalizedUserId = userId.trim();
  const currentRole = recipientRoles.get(normalizedUserId);
  if (currentRole === "leader") return;
  recipientRoles.set(normalizedUserId, role);
}

function setRecipientRoles(recipientRoles, userIds, role) {
  if (!Array.isArray(userIds)) return;
  for (const userId of userIds) {
    setRecipientRole(recipientRoles, userId, role);
  }
}

function memberRecords(taskData) {
  if (Array.isArray(taskData.members)) return taskData.members;
  if (taskData.members && typeof taskData.members === "object") {
    return Object.values(taskData.members);
  }
  return [];
}

function notificationRecipients(taskData, isPersonalTask, projectData = null) {
  const recipientRoles = new Map();

  if (isPersonalTask) {
    setRecipientRole(recipientRoles, taskData.assigneeId, "personal");
    setRecipientRoles(recipientRoles, taskData.assigneeIds, "personal");
    setRecipientRole(recipientRoles, taskData.creatorId, "personal");
    setRecipientRole(recipientRoles, taskData.userId, "personal");
    return [...recipientRoles].map(([userId, role]) => ({userId, role}));
  }

  setRecipientRole(recipientRoles, taskData.assigneeId, "member");
  setRecipientRoles(recipientRoles, taskData.assigneeIds, "member");

  for (const member of memberRecords(taskData)) {
    if (!member || typeof member !== "object") continue;
    setRecipientRole(recipientRoles, member.id, "member");
    setRecipientRole(recipientRoles, member.userId, "member");
    setRecipientRoles(recipientRoles, member.coAssigneeIds, "member");
  }

  setRecipientRole(recipientRoles, taskData.creatorId, "leader");
  setRecipientRole(recipientRoles, taskData.leaderId, "leader");
  setRecipientRole(recipientRoles, taskData.ownerId, "leader");
  if (projectData) {
    setRecipientRole(recipientRoles, projectData.leaderId, "leader");
    setRecipientRole(recipientRoles, projectData.ownerId, "leader");
    setRecipientRole(recipientRoles, projectData.creatorId, "leader");
  }

  return [...recipientRoles].map(([userId, role]) => ({userId, role}));
}

function groupNotificationCopy(flagToUpdate, role, taskTitle) {
  const isLeader = role === "leader";

  if (flagToUpdate.startsWith("custom_")) {
    const minutesBefore = parseInt(flagToUpdate.replace("custom_", ""), 10);
    const timeLabel = Number.isFinite(minutesBefore)
      ? customReminderLabel(minutesBefore)
      : "กำหนด";
    return isLeader
      ? {
        title: `⏳ อีก ${timeLabel} ถึงเวลาตรวจงาน`,
        body: `ภารกิจ "${taskTitle}" ใกล้ถึงกำหนดแล้ว เตรียมติดตามและตรวจความพร้อมของทีมได้เลย`,
      }
      : {
        title: `⏳ อีก ${timeLabel} ส่งงานกลุ่ม!`,
        body: `ภารกิจ "${taskTitle}" ใกล้ถึงกำหนดแล้ว ทุกคนพร้อมไหม?`,
      };
  }

  if (flagToUpdate === "notified1Week") {
    return isLeader
      ? {
        title: "⏳ อีก 1 สัปดาห์ถึงกำหนดส่งงานสมาชิก",
        body: `ภารกิจ "${taskTitle}" จะถึงกำหนดส่งในอีก 1 สัปดาห์ เตรียมติดตามความคืบหน้าของทีมได้เลย`,
      }
      : {
        title: "⏳ อีก 1 สัปดาห์ส่งงานกลุ่ม!",
        body: `ภารกิจ "${taskTitle}" มีกำหนดส่งสัปดาห์หน้า ทุกคนพร้อมไหม?`,
      };
  }

  if (flagToUpdate === "notified1Day") {
    return isLeader
      ? {
        title: "🚨 พรุ่งนี้ครบกำหนดส่งงานสมาชิก",
        body: `ภารกิจ "${taskTitle}" จะครบกำหนดพรุ่งนี้ อย่าลืมเช็กความพร้อมของทีม`,
      }
      : {
        title: "🚨 พรุ่งนี้เดดไลน์ภารกิจกลุ่ม!",
        body: `อย่าลืมช่วยกันปั่นภารกิจ "${taskTitle}" นะ พรุ่งนี้ต้องส่งแล้ว!`,
      };
  }

  if (flagToUpdate === "notified1Hour") {
    return isLeader
      ? {
        title: "🔥 อีก 1 ชั่วโมงถึงเวลาตรวจงาน",
        body: `ภารกิจ "${taskTitle}" เหลือเวลาให้สมาชิกส่งอีก 60 นาที เตรียมตรวจงานได้เลย`,
      }
      : {
        title: "🔥 1 ชั่วโมงสุดท้ายของภารกิจกลุ่ม!",
        body: `เร่งมือเข้าทุกคน! ภารกิจ "${taskTitle}" จะหมดเวลารับส่งในอีก 60 นาทีนี้`,
      };
  }

  if (flagToUpdate === "notifiedExact") {
    return isLeader
      ? {
        title: "⏰ หมดเวลาส่งงานของเหล่าสมาชิกแล้ว",
        body: `ได้เวลาตรวจงาน "${taskTitle}" แล้วครับ`,
      }
      : {
        title: "⏰ หมดเวลาส่งงานกลุ่มแล้ว!",
        body: `ภารกิจ "${taskTitle}" ถึงกำหนดเวลาส่งอย่างเป็นทางการแล้ว`,
      };
  }

  if (flagToUpdate === "notifiedFollowUp") {
    return isLeader
      ? {
        title: "❓ ถึงเวลาตรวจความคืบหน้าทีมแล้ว",
        body: `ภารกิจ "${taskTitle}" เลยเวลาส่งมา 30 นาทีแล้ว เข้าไปตรวจงานหรือแจ้งสมาชิกได้เลย`,
      }
      : {
        title: "❓ ภารกิจกลุ่มเสร็จหรือยังครับ?",
        body: `ภารกิจ "${taskTitle}" เลยเวลาส่งมา 30 นาทีแล้ว อย่าลืมเข้าไปอัปเดตสถานะของทีมกันด้วยนะครับ`,
      };
  }

  return {
    title: "⏰ แจ้งเตือนภารกิจกลุ่ม",
    body: `ภารกิจ "${taskTitle}" มีการแจ้งเตือนใหม่`,
  };
}

function isGroupTask(taskData) {
  const type = (taskData.type || "").toString().toLowerCase();
  if (type.includes("group")) return true;
  if (typeof taskData.projectId === "string" && taskData.projectId.trim()) {
    return true;
  }
  if (Array.isArray(taskData.members) && taskData.members.length > 0) {
    return true;
  }
  if (
    taskData.members &&
    typeof taskData.members === "object" &&
    Object.keys(taskData.members).length > 0
  ) {
    return true;
  }
  return Array.isArray(taskData.assigneeIds) && taskData.assigneeIds.length > 1;
}

function notificationTypeForFlag(flagToUpdate) {
  if (flagToUpdate === "notifiedExact") return "Deadline";
  if (flagToUpdate === "notifiedFollowUp") return "Follow-up";
  if (
    flagToUpdate === "notified1Week" ||
    flagToUpdate === "notified1Day" ||
    flagToUpdate === "notified1Hour"
  ) {
    return "Reminder";
  }
  return "Update";
}

function customReminderLabel(minutesBefore) {
  if (minutesBefore >= 10080 && minutesBefore % 10080 === 0) {
    return `${minutesBefore / 10080} สัปดาห์`;
  }
  if (minutesBefore >= 1440 && minutesBefore % 1440 === 0) {
    return `${minutesBefore / 1440} วัน`;
  }
  if (minutesBefore >= 60 && minutesBefore % 60 === 0) {
    return `${minutesBefore / 60} ชั่วโมง`;
  }
  return `${minutesBefore} นาที`;
}

function asMessageText(value, fallback = "") {
  if (value === null || value === undefined) return fallback;
  const text = value.toString().trim();
  return text.length > 0 ? text : fallback;
}

function notificationDataPayload(notificationData, userId, notificationId) {
  const payload = {
    notificationId,
    recipientId: userId,
    title: asMessageText(notificationData.title),
    body: asMessageText(notificationData.body),
    notificationType: asMessageText(notificationData.type, "Update"),
    notificationStage: asMessageText(notificationData.notificationStage),
    notificationKey: asMessageText(
      notificationData.notificationKey,
      `${notificationId}-${userId}`
    ),
    click_action: "FLUTTER_NOTIFICATION_CLICK",
  };

  const optionalFields = [
    "taskId",
    "taskType",
    "recipientRole",
    "actorId",
    "actorName",
    "actorAvatarUrl",
    "commentId",
    "friendRequestId",
  ];

  for (const field of optionalFields) {
    const value = asMessageText(notificationData[field]);
    if (value) payload[field] = value;
  }

  return payload;
}

// ฟังก์ชันสำหรับส่งการแจ้งเตือนแบบด่วนเมื่อเกิดเหตุการณ์ต่างๆ ในแอป
// เช่น เมื่อมีคนแสดงความคิดเห็น หรือมีการตอบรับคำขอเป็นเพื่อน
exports.pushInAppNotification = onCall({
  region: FUNCTION_REGION,
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const notifications = Array.isArray(request.data && request.data.notifications)
    ? request.data.notifications
    : [];

  if (notifications.length === 0) {
    return {sent: 0, skipped: 0, failed: 0};
  }

  if (notifications.length > 100) {
    throw new HttpsError(
      "invalid-argument",
      "A maximum of 100 notifications can be pushed per request."
    );
  }

  const db = admin.firestore();
  const messaging = admin.messaging();
  let sent = 0;
  let skipped = 0;
  let failed = 0;

  for (const item of notifications) {
    const userId = asMessageText(item && item.userId);
    const notificationId = asMessageText(item && item.notificationId);

    if (!userId || !notificationId) {
      skipped++;
      continue;
    }

    const notificationRef = db
      .collection("users")
      .doc(userId)
      .collection("notifications")
      .doc(notificationId);
    const snapshot = await notificationRef.get();

    if (!snapshot.exists) {
      skipped++;
      continue;
    }

    const notificationData = snapshot.data() || {};

    if (notificationData.suppressPush === true) {
      console.log(`ℹ️ ข้าม push จาก notification ${notificationId}: suppressPush=true`);
      skipped++;
      continue;
    }

    if (notificationData.deletedAt) {
      console.log(`ℹ️ ข้าม push จาก notification ${notificationId}: ถูกลบแล้ว`);
      skipped++;
      continue;
    }

    if (notificationData.pushStatus === "sent") {
      skipped++;
      continue;
    }

    const notificationType = asMessageText(notificationData.type, "Update");
    if (!CLIENT_PUSH_NOTIFICATION_TYPES.has(notificationType)) {
      skipped++;
      continue;
    }

    const actorId = asMessageText(notificationData.actorId);
    if (actorId !== request.auth.uid) {
      console.log(
        `ℹ️ ข้าม push ${notificationId}: actorId ไม่ตรงกับผู้เรียก function`
      );
      skipped++;
      continue;
    }

    const title = asMessageText(notificationData.title, "มีแจ้งเตือนใหม่");
    const body = asMessageText(
      notificationData.body,
      "เปิดแอปเพื่อดูรายละเอียดล่าสุด"
    );
    const notificationKey = asMessageText(
      notificationData.notificationKey,
      `${notificationId}-${userId}`
    );
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      console.log(`ℹ️ ไม่พบผู้ใช้ ${userId} สำหรับ notification ${notificationId}`);
      skipped++;
      continue;
    }

    const userData = userDoc.data() || {};
    const fcmToken = asMessageText(userData.fcmToken);
    if (!fcmToken) {
      console.log(`ℹ️ User ${userId} ไม่มี fcmToken ข้าม push notification`);
      await snapshot.ref.set({
        pushStatus: "missing-token",
        pushCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      skipped++;
      continue;
    }

    const message = {
      data: notificationDataPayload(notificationData, userId, notificationId),
      android: {
        priority: "high",
        ttl: 60 * 60 * 1000,
      },
      token: fcmToken,
    };

    try {
      await messaging.send(message);
      await snapshot.ref.set({
        pushStatus: "sent",
        pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
        pushNotificationType: notificationType,
      }, { merge: true });
      console.log(`🟩 ส่ง push จาก in-app notification สำเร็จ -> User: ${userId}`);
      sent++;
    } catch (err) {
      const updateData = {
        pushStatus: "failed",
        pushError: asMessageText(err && err.message, "unknown-error"),
        pushFailedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (isInvalidFcmTokenError(err)) {
        updateData.pushStatus = "invalid-token";
        updateData.invalidTokenClearedAt =
          admin.firestore.FieldValue.serverTimestamp();
        await userDoc.ref.set({
          fcmToken: admin.firestore.FieldValue.delete(),
          lastInvalidFcmTokenAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      await snapshot.ref.set({
        ...updateData,
      }, { merge: true });
      console.error(`🟥 ส่ง push จาก in-app notification ล้มเหลว -> User: ${userId}:`, err);
      failed++;
    }
  }

  return {sent, skipped, failed};
});

// ฟังก์ชันนี้เหมือนนาฬิกาปลุกที่ตั้งเวลาให้ทำงานอัตโนมัติทุกๆ 1 นาที
// หน้าที่หลักคือคอยเช็กว่ามีงานไหนใกล้ถึงกำหนดส่ง หรือเลยเวลาส่งไปแล้วบ้าง
// เพื่อจะได้ส่งข้อความแจ้งเตือนเตือนความจำให้กับสมาชิกหรือหัวหน้างาน
exports.checkDeadlinesAndPushNotify = onSchedule({
  schedule: "* * * * *", // ตั้งเวลาให้ทำงานทุก 1 นาที
  region: FUNCTION_REGION,
  timeZone: "Asia/Bangkok", // ใช้เวลาตามประเทศไทย
}, async (event) => {
  const db = admin.firestore();
  const messaging = admin.messaging();
  const now = admin.firestore.Timestamp.now();
  const nowMs = now.toMillis();

  const ONE_HOUR_MS = 60 * 60 * 1000;
  const ONE_DAY_MS = 24 * 60 * 60 * 1000;
  const ONE_WEEK_MS = 7 * 24 * 60 * 60 * 1000;

  try {
    const tasksSnapshot = await db
      .collection("tasks")
      .where("status", "in", ["todo", "inProgress", "pending"])
      .get();
    console.log(`🔍 รันรอบ 1 นาที! พบภารกิจที่กำลังดำเนินการ: ${tasksSnapshot.size} ชิ้น`);

    for (const doc of tasksSnapshot.docs) {
      const taskData = doc.data();
      const taskId = doc.id;

      if (taskData.isDeleted === true) {
        continue;
      }

      const isTaskFinished =
        taskData.status === "completed" || taskData.isCompleted === true;
      if (isTaskFinished) {
        console.log(`⏭️ ภารกิจ ${taskId} เสร็จแล้ว ข้ามการแจ้งเตือน`);
        continue;
      }
      
      const targetDate = taskData.dateTime || taskData.dueDate;
      if (!targetDate) continue;

      const dueDateMs = targetDate.toMillis();
      const timeRemaining = dueDateMs - nowMs;
      
      let shouldNotify = false;
      let notificationTitle = "";
      let notificationBody = "";
      let updatePayload = {};
      let notifType = "Reminder";
      let flagToUpdateTag = "";

      // 🔥 ดึงตัวแปรแยกว่าเป็นภารกิจส่วนตัวหรือภารกิจกลุ่ม
      // ภารกิจกลุ่มต้องชนะ category เสมอ เพราะ category อาจยังเป็น "Personal"
      const isGroup = isGroupTask(taskData);
      const isPersonalTask = !isGroup;
      const taskTitle = taskData.title || 'ไม่มีชื่อ';

      // -----------------------------------------------------------------
      // 🔥 เงื่อนไขใหม่: วนลูปเช็กแจ้งเตือนแบบ Custom Reminders
      // -----------------------------------------------------------------
      const customReminders = taskData.customReminders || {};
      const reminderEntries = Object.entries(customReminders)
        .map(([minutesStr, isNotified]) => ({
          minutesStr,
          isNotified,
          minutesBefore: parseInt(minutesStr, 10),
        }))
        .filter((entry) => Number.isFinite(entry.minutesBefore) && entry.minutesBefore > 0)
        .sort((a, b) => a.minutesBefore - b.minutesBefore);

      for (const entry of reminderEntries) {
        if (entry.isNotified) continue;

        const reminderTargetMs = entry.minutesBefore * 60 * 1000;
        if (timeRemaining <= reminderTargetMs && timeRemaining > 0) {
          const timeLabel = customReminderLabel(entry.minutesBefore);
          shouldNotify = true;
          updatePayload[`customReminders.${entry.minutesStr}`] = true;
          flagToUpdateTag = `custom_${entry.minutesStr}`;
          notifType = "Reminder";

          if (isPersonalTask) {
            notificationTitle = `⏳ ล่วงหน้า ${timeLabel}!`;
            notificationBody = `อย่าลืมเตรียมตัวสำหรับภารกิจ "${taskTitle}" นะ ใกล้ถึงกำหนดแล้ว`;
          } else {
            notificationTitle = `⏳ อีก ${timeLabel} ส่งงานกลุ่ม!`;
            notificationBody = `ภารกิจ "${taskTitle}" ใกล้ถึงกำหนดแล้ว ทุกคนพร้อมไหม?`;
          }
          break;
        }
      }
      // -----------------------------------------------------------------
      // 🔥 เงื่อนไข: ถึงเวลาเป๊ะ!
      // -----------------------------------------------------------------
      if (!shouldNotify && !taskData.notifiedExact && timeRemaining <= 0) {
        shouldNotify = true;
        updatePayload["notifiedExact"] = true;
        flagToUpdateTag = "notifiedExact";
        notifType = "Deadline";
        if (isGroup) {
          notificationTitle = `⏰ หมดเวลาส่งงานกลุ่มแล้ว!`;
          notificationBody = `ภารกิจ "${taskTitle}" ถึงกำหนดเวลาส่งอย่างเป็นทางการแล้ว`;
        } else {
          notificationTitle = `🎯 ถึงเวลาภารกิจของคุณแล้ว!`;
          notificationBody = `ได้เวลาลุยภารกิจ "${taskTitle}" ที่สร้างไว้แล้ว ขอให้ลื่นไหลและสำเร็จนะ!`;
        }
      }
      // -----------------------------------------------------------------
      // 🔥 เงื่อนไข: ระบบตามภารกิจ (เลยเวลามา 30 นาที และยังไม่เสร็จ)
      // -----------------------------------------------------------------
      else if (!shouldNotify && !taskData.notifiedFollowUp && timeRemaining <= -(30 * 60 * 1000)) {
        shouldNotify = true;
        updatePayload["notifiedFollowUp"] = true;
        flagToUpdateTag = "notifiedFollowUp";
        notifType = "Follow-up";
        if (isGroup) {
          notificationTitle = `❓ ภารกิจกลุ่มเสร็จหรือยังครับ?`;
          notificationBody = `ภารกิจ "${taskTitle}" เลยเวลาส่งมา 30 นาทีแล้ว อย่าลืมเข้าไปอัปเดตสถานะด้วยนะครับ`;
        } else {
          notificationTitle = `❓ อัปเดตความคืบหน้ากันหน่อย`;
          notificationBody = `ภารกิจ "${taskTitle}" สำเร็จลุล่วงหรือยัง? ถ้าเสร็จแล้วอย่าลืมกดทำเครื่องหมายนะ`;
        }
      }

      // --- ส่วนของการยิงข้อความ (เพิ่ม Tag กัน Android บล็อกสแปม) ---
      if (shouldNotify && Object.keys(updatePayload).length > 0) {
        let projectData = null;
        if (
          isGroup &&
          typeof taskData.projectId === "string" &&
          taskData.projectId.trim().length > 0
        ) {
          const projectDoc = await db
            .collection("projects")
            .doc(taskData.projectId.trim())
            .get();
          if (projectDoc.exists) {
            projectData = projectDoc.data();
          }
        }

        const recipients = notificationRecipients(
          taskData,
          isPersonalTask,
          projectData
        );
        console.log(`🎯 ภารกิจ ${taskId} เข้าเงื่อนไขเตือน [${flagToUpdateTag}]`);
        console.log(
          `🧭 ประเภทภารกิจ ${taskId}: ${isGroup ? "group" : "personal"} ` +
          `(type=${taskData.type || "-"}, category=${taskData.category || "-"})`
        );
        console.log(`👥 ผู้รับแจ้งเตือนภารกิจ ${taskId}: ${recipients.length} คน`);

        if (recipients.length === 0) {
          console.log(`⚠️ ภารกิจ ${taskId} เข้าเงื่อนไขเตือน [${flagToUpdateTag}] แต่ไม่พบผู้รับแจ้งเตือน (ข้ามการอัปเดต flag)`);
          continue;
        }

        for (const recipient of recipients) {
          const userId = recipient.userId;
          const userDoc = await db.collection("users").doc(userId).get();
          if (!userDoc.exists) continue;

          const userData = userDoc.data();

          // -----------------------------------------------------------------
          // 🔥 จุดที่อัปเดต: เช็กสวิตช์ Master Switch ของผู้ใช้
          // (ถ้าไม่มีฟิลด์นี้ ให้ถือว่าเปิดแจ้งเตือนเป็นค่าเริ่มต้น)
          // -----------------------------------------------------------------
          const isNotificationEnabled = userData.isNotificationEnabled !== false;

          if (!isNotificationEnabled) {
            console.log(`🔕 ผู้ใช้ ${userId} ปิดการแจ้งเตือนไว้ (ข้ามการส่ง)...`);
            continue; // 🛑 สั่งให้ข้ามการทำภารกิจของลูปนี้ไปเลย ไม่เซฟ ไม่ยิง FCM
          }

          const copy = isGroup
            ? groupNotificationCopy(flagToUpdateTag, recipient.role, taskTitle)
            : {title: notificationTitle, body: notificationBody};
          const notificationKey =
            `${taskId}-${flagToUpdateTag}-${recipient.userId}-${recipient.role}`;
          const notificationType = notifType;

          try {
            const expireDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
            await db
              .collection("users")
              .doc(userId)
              .collection("notifications")
              .add({
                title: copy.title,
                body: copy.body,
                type: notificationType,
                isRead: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                expireAt: admin.firestore.Timestamp.fromDate(expireDate),
                taskId: taskId,
                taskType: isGroup ? "group" : "personal",
                recipientRole: recipient.role,
                notificationStage: flagToUpdateTag,
                notificationKey: notificationKey,
                suppressPush: true,
              });
            console.log(
              `💾 บันทึก In-App Notification สำเร็จ! [${flagToUpdateTag}] ` +
              `-> User: ${recipient.userId} (${recipient.role})`
            );
          } catch (err) {
            console.error(
              `🟥 บันทึก In-App Notification ล้มเหลว -> User: ${recipient.userId}:`,
              err
            );
          }

          const fcmToken = asMessageText(userData.fcmToken);
          if (!fcmToken) {
            console.log(`ℹ️ User ${recipient.userId} ไม่มี fcmToken ข้าม FCM`);
            continue;
          }

          const message = {
            data: {
              title: copy.title,
              body: copy.body,
              taskId: taskId,
              taskType: isGroup ? "group" : "personal",
              recipientRole: recipient.role,
              notificationStage: flagToUpdateTag,
              notificationType: notificationType,
              notificationKey: notificationKey,
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            // ส่ง data-only message เพื่อให้ Client จัดการแสดง notification เอง
            // ทำให้ควบคุม เสียง, Heads-up, และ vibration ได้ครบทุกสถานะ
            android: {
              priority: "high",
              ttl: 60 * 60 * 1000,
            },
            token: fcmToken,
          };

          try {
            await messaging.send(message);
            console.log(
              `🟩 ส่งข้อความสำเร็จ! [${flagToUpdateTag}] ` +
              `-> User: ${recipient.userId} (${recipient.role})`
            );
          } catch (err) {
            if (isInvalidFcmTokenError(err)) {
              await userDoc.ref.set({
                fcmToken: admin.firestore.FieldValue.delete(),
                lastInvalidFcmTokenAt:
                  admin.firestore.FieldValue.serverTimestamp(),
              }, { merge: true });
            }
            console.error(`🟥 ส่งข้อความล้มเหลว -> User: ${recipient.userId}:`, err);
          }
        }

        // อัปเดตแฟลกที่แจ้งเตือนไปแล้วให้เป็น true
        await db.collection("tasks").doc(taskId).update(updatePayload);
      }
    }
  } catch (error) {
    console.error("เกิดข้อผิดพลาดในการรันระบบจับเวลา:", error);
  }
  return null;
});
