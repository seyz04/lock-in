# Builds French_Reservoir.apkg from cards.csv. Stable IDs: re-importing updates cards instead of duplicating.
import csv, genanki, os
here = os.path.dirname(os.path.abspath(__file__))
model = genanki.Model(1607392319, 'Sey French (2-way)',
    fields=[{'name': 'Front'}, {'name': 'Back'}],
    templates=[
        {'name': 'FR→EN', 'qfmt': '<div class=q>{{Front}}</div>', 'afmt': '{{FrontSide}}<hr id=answer><div class=a>{{Back}}</div>'},
        {'name': 'EN→FR', 'qfmt': '<div class=a>{{Back}}</div><div class=hint>Say it in French, out loud</div>', 'afmt': '{{FrontSide}}<hr id=answer><div class=q>{{Front}}</div>'},
    ],
    css='.card{font-family:-apple-system,Helvetica;font-size:22px;text-align:center;padding:20px}.q{font-weight:600}.a{color:#555}.hint{font-size:14px;color:#999;margin-top:10px}')
deck = genanki.Deck(2059400110, 'French::1 Speaking')
with open(os.path.join(here, 'cards.csv'), newline='', encoding='utf-8') as f:
    for row in csv.DictReader(f, delimiter='\t'):
        deck.add_note(genanki.Note(model=model, fields=[row['front'], row['back']],
                                   tags=row['tags'].split(), guid=genanki.guid_for(row['front'])))
out = os.path.join(here, 'French_Reservoir.apkg')
genanki.Package(deck).write_to_file(out)
print(len(deck.notes), 'notes →', out)
