import re

with open("lib/tabs/order_form_tab.dart", "r") as f:
    content = f.read()

target1 = """                                  ],
                                ),
                              ],
                            )
                          : Row("""

replacement1 = """                                  ],
                                ),
                              ],
                            ),
                          )
                          : Row("""

target2 = """                                    const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 20),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),"""

replacement2 = """                                    const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 20),
                                  ],
                                ),
                              ],
                            ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),"""

content = content.replace(target1, replacement1)
content = content.replace(target2, replacement2)

with open("lib/tabs/order_form_tab.dart", "w") as f:
    f.write(content)

