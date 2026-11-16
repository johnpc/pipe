from google import genai
from google.genai import types
import os
client = genai.Client(api_key=os.environ['GEMINI_API_KEY'])
banner = open('/Users/xss/repo/pipe/docs/banner.png','rb').read()
def gen(name, prompt, refs):
    parts = [prompt] + [types.Part.from_bytes(data=d, mime_type='image/png') for d in refs]
    r = client.models.generate_content(model='gemini-3-pro-image', contents=parts,
        config=types.GenerateContentConfig(response_modalities=['image','text']))
    for p in r.candidates[0].content.parts:
        if getattr(p,'inline_data',None) and p.inline_data:
            open(name,'wb').write(p.inline_data.data); print('saved', name); return True
    print('no image', name); return False
common = ("Design an iOS app icon, exactly square 1024x1024, filling the whole canvas edge to edge with NO rounded corners, "
          "NO drop shadow outside the square, NO text or letters other than what is described, NO mockup or device frame. "
          "Use the attached banner as the style and palette reference: warm coral (#FF8A65) and soft teal (#5FC8BF) on deep navy, "
          "with a subtle soft glow on the glowing elements. Polished, modern, high-end app-icon illustration with gentle depth. ")
concepts = {
 'tube':  "The mark: a thick, rounded coral tube bent into the shape of a lowercase letter p — the 'pipe' — with a glowing teal "
          "audio waveform flowing out of its open end to the right. Centered, generous margins. ",
 'wave':  "The mark: a glowing teal audio waveform that flows into a bold coral play triangle on the right, "
          "as if the sound becomes the play button. Centered, generous margins. ",
 'pipeplay': "The mark: a short section of a rounded coral pipe seen slightly from the side, with a glowing teal play triangle "
          "inside its opening and faint teal sound ripples emanating from it. Centered, generous margins. ",
}
for key, concept in concepts.items():
    ok = gen(f'g-{key}-dark.png', common + concept + "Background: the banner's deep navy, slightly darker at the bottom. This is the DARK MODE icon.", [banner])
    if ok:
        gen(f'g-{key}-light.png', common + concept +
            "Now make the LIGHT MODE icon of the attached dark icon (second image): keep the exact same mark, composition and framing; "
            "change only the background to a warm off-white (#FFF4EC) with a very subtle pale peach vignette, and reduce the glow so "
            "the mark stays crisp on the light background. Coral and teal stay the same hues.", [banner, open(f'g-{key}-dark.png','rb').read()])
