# Frequently Asked Questions

```@contents
Pages   = ["faq-page.md"]
Depth = 3:4
```


#### How do I run GEMS?

GEMS is an open Julia package.
Just install Julia, and install the package as shown [here](@ref home).
We recommend using [Visual Studio Code](https://code.visualstudio.com/) as an IDE.


#### What are the system requirements to run GEMS?

GEMS needs roughly ~500MB of system memory per million individuals, without post-processing.
Adding on post-processing roughly doubles the required system memory.
The default model contains 100,000 individuals which should only take a couple megabytes.


#### Can I add my own populations to GEMS?

Yes. There are many ways to load your own population model via CSV- and JLD2 files or passing a dataframe that contains your model.
Look up the [tutorial on creating populations](@ref tut_pops).


#### Is GEMS still being developed?

Yes. As part of the [ADAPTI-M project](https://monid.net/forschungsverbuende/optimagent-2/) new features are constantly developed.


#### Can I use GEMS in my research project?

Of course! GEMS has an open source license (GPLv3) permitting any kind of use as long as your code will be published under the same license.
For any publications, please cite the papers referenced on the repository landing page.
