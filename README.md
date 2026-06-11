# CommunityShare-Final-Year-Project

## Firestore seed data

The repository includes a Firestore seeder at [`scripts/seed_firestore.py`](./scripts/seed_firestore.py).

Run it with:

```powershell
pip install firebase-admin
python scripts/seed_firestore.py --service-account path\to\serviceAccountKey.json
```

Use `--dry-run` first if you want to verify the document counts before writing anything.
