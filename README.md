This is a tool for displaying a text together with its translation so that each sentence from the source text is followed by its translation.

You provide a source text and a (human) translated text and machine translation is used to correlate sentences between the two texts and then display the two texts interleaved.

[Here is an example of the output](https://rawgit.com/wlevine/translation_interleaver/master/texts/underground_chap1.html). Unfortunately it gets the first sentence wrong, but other than that it does pretty well.

This tool requires the bing\_translator gem and the pragmatic\_segmenter gem.

Before running, you will need a (free) Client ID and secret for Microsoft translator.

How to run:
```
./translate.rb -i texts/underground_chap1_ru.txt -o texts/gen_underground_chap1.yaml -s ru -t en -c [client_id] -k [secret]
./interleave.rb -y texts/gen_underground_chap1.yaml -m texts/underground_chap1_en.txt -o texts/gen_underground_chap1.html -t en
```

The sample texts in the texts/ directory are all public domain. The code is under the MIT license.

Caveats:

TODO:


