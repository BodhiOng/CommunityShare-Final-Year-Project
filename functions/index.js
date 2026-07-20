const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();

const COLLECTIONS = {
  user: "USER",
  donor: "DONOR",
  recipient: "RECIPIENT",
  hub: "COMMUNITY_HUB",
  admin: "ADMIN",
  itemListing: "ITEM_LISTING",
  itemRequest: "ITEM_REQUEST",
  handover: "HANDOVER",
  report: "REPORT",
  donationStatusHistory: "DONATION_STATUS_HISTORY",
};

exports.registerUser = onCall(async (request) => {
  if (request.auth?.uid) {
    throw new HttpsError(
      "failed-precondition",
      "Sign out before creating a new account.",
    );
  }

  const data = request.data || {};
  const email = requiredString(data.email, "email");
  const password = requiredString(data.password, "password");
  const fullName = requiredString(data.fullName, "fullName");
  const role = normalizePublicRole(data.role);
  const status = "inactive";
  const phoneCountryCode = optionalString(data.phoneCountryCode);
  const phoneLocalNumber = optionalString(data.phoneLocalNumber);
  const recipientType = optionalString(data.recipientType);
  const hubDetails = normalizeHubDetails(data.hubDetails || {}, status);

  if (password.length < 6) {
    throw new HttpsError(
      "invalid-argument",
      "Password must be at least 6 characters long.",
    );
  }

  const createdUser = await createAuthUser({
    email,
    password,
    displayName: fullName,
    disabled: false,
  });

  try {
    await createUserDocuments({
      userId: createdUser.uid,
      fullName,
      email,
      phoneCountryCode,
      phoneLocalNumber,
      role,
      status,
      recipientType,
      hubDetails,
    });
  } catch (error) {
    await auth.deleteUser(createdUser.uid).catch(() => {});
    throw error;
  }

  return {
    userId: createdUser.uid,
    role,
    status,
  };
});

exports.createManagedUser = onCall(async (request) => {
  const callerUid = await assertAdminCaller(request);
  void callerUid;

  const data = request.data || {};
  const email = requiredString(data.email, "email");
  const password = requiredString(data.password, "password");
  const fullName = requiredString(data.fullName, "fullName");
  const role = normalizeRole(data.role);
  const status = normalizeStatus(data.status);
  const phoneCountryCode = optionalString(data.phoneCountryCode);
  const phoneLocalNumber = optionalString(data.phoneLocalNumber);
  const recipientType = optionalString(data.recipientType);
  const hubDetails = normalizeHubDetails(data.hubDetails || {}, status);

  const createdUser = await createAuthUser({
    email,
    password,
    displayName: fullName,
    disabled: false,
  });

  try {
    await createUserDocuments({
      userId: createdUser.uid,
      fullName,
      email,
      phoneCountryCode,
      phoneLocalNumber,
      role,
      status,
      recipientType,
      hubDetails,
    });
  } catch (error) {
    await auth.deleteUser(createdUser.uid).catch(() => {});
    throw error;
  }

  return {userId: createdUser.uid};
});

async function createUserDocuments({
  userId,
  fullName,
  email,
  phoneCountryCode,
  phoneLocalNumber,
  role,
  status,
  recipientType,
  hubDetails,
}) {
  await db.runTransaction(async (transaction) => {
    const userRef = db.collection(COLLECTIONS.user).doc(userId);
    const existingUser = await transaction.get(userRef);
    if (existingUser.exists) {
      throw new HttpsError(
        "already-exists",
        "A USER record already exists for this auth user.",
      );
    }

    transaction.set(userRef, {
      userId,
      fullName,
      email,
      phoneCountryCode,
      phoneLocalNumber,
      role,
      status,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    writeRoleDocument({
      transaction,
      userId,
      role,
      status,
      recipientType,
      hubDetails,
    });
  });
}

async function createAuthUser(userDetails) {
  try {
    return await auth.createUser(userDetails);
  } catch (error) {
    if (error?.code === "auth/email-already-exists") {
      throw new HttpsError(
        "already-exists",
        "An account already exists for this email.",
      );
    }
    throw error;
  }
}

exports.deleteManagedUser = onCall(async (request) => {
  const callerUid = await assertAdminCaller(request);
  const userId = requiredString(request.data?.userId, "userId");

  if (callerUid === userId) {
    throw new HttpsError(
      "failed-precondition",
      "The signed-in admin cannot delete their own account.",
    );
  }

  const refsToDelete = await collectUserLinkedDocumentRefs(userId);
  await deleteDocumentRefs([...refsToDelete.values()]);

  try {
    await auth.deleteUser(userId);
  } catch (error) {
    if (error?.code !== "auth/user-not-found") {
      throw error;
    }
  }

  return {
    deletedUserId: userId,
    deletedFirestoreDocuments: refsToDelete.size,
  };
});

exports.promoteManagedUserToAdmin = onCall(async (request) => {
  await assertAdminCaller(request);

  const data = request.data || {};
  const userId = requiredString(data.userId, "userId");
  const fullName = requiredString(data.fullName, "fullName");
  const email = requiredString(data.email, "email");
  const phoneCountryCode = optionalString(data.phoneCountryCode);
  const phoneLocalNumber = optionalString(data.phoneLocalNumber);
  const status = normalizeStatus(data.status);

  const userRef = db.collection(COLLECTIONS.user).doc(userId);
  const userSnapshot = await userRef.get();
  if (!userSnapshot.exists) {
    throw new HttpsError("not-found", "User record not found.");
  }

  const currentData = userSnapshot.data() || {};
  const currentRole = normalizeRole(currentData.role);
  if (currentRole === "admin") {
    throw new HttpsError(
      "failed-precondition",
      "This user is already an admin.",
    );
  }

  const refsToDelete = await collectUserLinkedDocumentRefs(userId, {
    includeUserDoc: false,
  });
  await deleteDocumentRefs([...refsToDelete.values()]);

  await db.runTransaction(async (transaction) => {
    transaction.set(
      userRef,
      {
        userId,
        fullName,
        email,
        phoneCountryCode,
        phoneLocalNumber,
        role: "admin",
        status,
        createdAt:
          currentData.createdAt || admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    transaction.set(db.collection(COLLECTIONS.admin).doc(userId), {
      adminId: userId,
      userId,
    });
  });

  try {
    await auth.updateUser(userId, {
      email,
      displayName: fullName,
      disabled: status !== "active",
    });
  } catch (error) {
    if (error?.code !== "auth/user-not-found") {
      throw error;
    }
  }

  return {
    promotedUserId: userId,
    deletedFirestoreDocuments: refsToDelete.size,
  };
});

async function assertAdminCaller(request) {
  const callerUid = optionalString(request.auth?.uid);
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const userSnapshot = await db.collection(COLLECTIONS.user).doc(callerUid).get();
  if (!userSnapshot.exists) {
    throw new HttpsError("permission-denied", "Admin user record not found.");
  }

  const userData = userSnapshot.data() || {};
  const role = normalizeRole(userData.role);
  const status = normalizeStatus(userData.status || "active");

  if (role !== "admin" || status !== "active") {
    throw new HttpsError(
      "permission-denied",
      "Only active admins can manage users.",
    );
  }

  return callerUid;
}

function writeRoleDocument({
  transaction,
  userId,
  role,
  status,
  recipientType,
  hubDetails,
}) {
  switch (role) {
    case "donor":
      transaction.set(db.collection(COLLECTIONS.donor).doc(userId), {
        donorId: userId,
        userId,
      });
      break;
    case "recipient":
      transaction.set(db.collection(COLLECTIONS.recipient).doc(userId), {
        recipientId: userId,
        userId,
        recipientType,
      });
      break;
    case "hub":
      transaction.set(db.collection(COLLECTIONS.hub).doc(userId), {
        hubId: hubDetails.hubId || userId,
        userId,
        hubName: hubDetails.hubName,
        address: hubDetails.address,
        operatingHours: hubDetails.operatingHours,
        contactNumber: hubDetails.contactNumber,
        status,
      });
      break;
    case "admin":
      transaction.set(db.collection(COLLECTIONS.admin).doc(userId), {
        adminId: userId,
        userId,
      });
      break;
    default:
      throw new HttpsError("invalid-argument", `Unsupported role: ${role}`);
  }
}

async function loadRoleLinks(userId) {
  const [donorSnapshot, recipientSnapshot, hubSnapshot, adminSnapshot] =
    await Promise.all([
      db.collection(COLLECTIONS.donor).where("userId", "==", userId).get(),
      db.collection(COLLECTIONS.recipient).where("userId", "==", userId).get(),
      db.collection(COLLECTIONS.hub).where("userId", "==", userId).get(),
      db.collection(COLLECTIONS.admin).where("userId", "==", userId).get(),
    ]);

  return {
    donorIds: donorSnapshot.docs
      .map((doc) => optionalString(doc.data().donorId) || doc.id)
      .filter(Boolean),
    recipientIds: recipientSnapshot.docs
      .map((doc) => optionalString(doc.data().recipientId) || doc.id)
      .filter(Boolean),
    hubIds: hubSnapshot.docs
      .map((doc) => optionalString(doc.data().hubId) || doc.id)
      .filter(Boolean),
    adminIds: adminSnapshot.docs
      .map((doc) => optionalString(doc.data().adminId) || doc.id)
      .filter(Boolean),
  };
}

async function collectUserLinkedDocumentRefs(userId, options = {}) {
  const includeUserDoc = options.includeUserDoc !== false;
  const roleLinks = await loadRoleLinks(userId);
  const donorIds = new Set(roleLinks.donorIds);
  const recipientIds = new Set(roleLinks.recipientIds);
  const hubIds = new Set(roleLinks.hubIds);

  donorIds.add(userId);
  recipientIds.add(userId);

  const refsToDelete = new Map();
  const requestIds = new Set();
  const itemIds = new Set();

  await collectDocsByField(refsToDelete, COLLECTIONS.report, "reporterUserId", [
    userId,
  ]);
  await collectDocsByField(refsToDelete, COLLECTIONS.report, "reportedUserId", [
    userId,
  ]);
  await collectDocsByField(
    refsToDelete,
    COLLECTIONS.donationStatusHistory,
    "changedByUserId",
    [userId],
  );
  await collectDocsByField(refsToDelete, COLLECTIONS.admin, "userId", [userId]);
  await collectDocsByField(refsToDelete, COLLECTIONS.donor, "userId", [userId]);
  await collectDocsByField(refsToDelete, COLLECTIONS.recipient, "userId", [
    userId,
  ]);
  await collectDocsByField(refsToDelete, COLLECTIONS.hub, "userId", [userId]);

  for (const donorId of donorIds) {
    const listingSnapshots = await db
      .collection(COLLECTIONS.itemListing)
      .where("donorId", "==", donorId)
      .get();
    listingSnapshots.docs.forEach((doc) => {
      refsToDelete.set(doc.ref.path, doc.ref);
      itemIds.add(optionalString(doc.data().itemId) || doc.id);
    });
  }

  for (const recipientId of recipientIds) {
    await collectRequestsByField(
      refsToDelete,
      requestIds,
      "recipientId",
      recipientId,
    );
  }

  for (const hubId of hubIds) {
    await collectRequestsByField(refsToDelete, requestIds, "hubId", hubId);
    await collectDocsByField(refsToDelete, COLLECTIONS.handover, "hubId", [
      hubId,
    ]);
  }

  for (const itemId of itemIds) {
    await collectDocsByField(refsToDelete, COLLECTIONS.report, "itemId", [itemId]);

    const requestSnapshots = await db
      .collection(COLLECTIONS.itemRequest)
      .where("itemId", "==", itemId)
      .get();
    requestSnapshots.docs.forEach((doc) => {
      refsToDelete.set(doc.ref.path, doc.ref);
      requestIds.add(optionalString(doc.data().requestId) || doc.id);
    });
  }

  for (const requestId of requestIds) {
    await collectDocsByField(refsToDelete, COLLECTIONS.handover, "requestId", [
      requestId,
    ]);
    await collectDocsByField(
      refsToDelete,
      COLLECTIONS.donationStatusHistory,
      "requestId",
      [requestId],
    );
  }

  if (includeUserDoc) {
    refsToDelete.set(userRefPath(userId), db.collection(COLLECTIONS.user).doc(userId));
  }

  return refsToDelete;
}

function userRefPath(userId) {
  return db.collection(COLLECTIONS.user).doc(userId).path;
}

async function collectRequestsByField(refsToDelete, requestIds, field, value) {
  const snapshot = await db
    .collection(COLLECTIONS.itemRequest)
    .where(field, "==", value)
    .get();
  snapshot.docs.forEach((doc) => {
    refsToDelete.set(doc.ref.path, doc.ref);
    requestIds.add(optionalString(doc.data().requestId) || doc.id);
  });
}

async function collectDocsByField(refsToDelete, collection, field, values) {
  for (const value of values) {
    if (!optionalString(value)) {
      continue;
    }
    const snapshot = await db
      .collection(collection)
      .where(field, "==", value)
      .get();
    snapshot.docs.forEach((doc) => {
      refsToDelete.set(doc.ref.path, doc.ref);
    });
  }
}

async function deleteDocumentRefs(refs) {
  const batchSize = 400;
  for (let index = 0; index < refs.length; index += batchSize) {
    const batch = db.batch();
    refs.slice(index, index + batchSize).forEach((ref) => batch.delete(ref));
    await batch.commit();
  }
}

function normalizeRole(value) {
  const role = optionalString(value).toLowerCase();
  if (!["donor", "recipient", "hub", "admin"].includes(role)) {
    throw new HttpsError("invalid-argument", `Invalid role: ${value}`);
  }
  return role;
}

function normalizePublicRole(value) {
  const role = optionalString(value).toLowerCase();
  if (!["donor", "recipient", "hub"].includes(role)) {
    throw new HttpsError("invalid-argument", `Invalid role: ${value}`);
  }
  return role;
}

function normalizeStatus(value) {
  const status = optionalString(value).toLowerCase();
  if (!["active", "inactive", "suspended", "deleted"].includes(status)) {
    throw new HttpsError("invalid-argument", `Invalid status: ${value}`);
  }
  return status;
}

function normalizeHubDetails(value, status) {
  return {
    hubId: optionalString(value.hubId),
    hubName: optionalString(value.hubName),
    address: optionalString(value.address),
    operatingHours: optionalString(value.operatingHours),
    contactNumber: optionalString(value.contactNumber),
    status,
  };
}

function requiredString(value, field) {
  const normalized = optionalString(value);
  if (!normalized) {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  return normalized;
}

function optionalString(value) {
  return value == null ? "" : String(value).trim();
}
